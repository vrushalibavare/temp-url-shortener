resource "aws_dynamodb_table" "url_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_id"

  attribute {
    name = "short_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-shortener-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_ddb_policy" {
  name   = "lambda-dynamodb-policy"
  policy = data.aws_iam_policy_document.lambda_ddb_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_ddb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ddb_policy.arn
}

resource "aws_lambda_function" "create_url" {
  filename         = data.archive_file.lambda_createurl_zip.output_path
  function_name    = "createUrl"
  handler          = "app.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = data.archive_file.lambda_createurl_zip.output_base64sha256
  environment {
    variables = {
      DB_NAME   = var.dynamodb_table_name
      REGION_AWS = var.region
      APP_URL   = "https://${var.domain_name}/"
      MIN_CHAR  = "12"
      MAX_CHAR  = "16"
    }
  }
}

resource "aws_lambda_function" "retrieve_url" {
  filename         = data.archive_file.lambda_retrieveurl_zip.output_path
  function_name    = "retrieveUrl"
  handler          = "app.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = data.archive_file.lambda_retrieveurl_zip.output_base64sha256
  environment {
    variables = {
      DB_NAME    = var.dynamodb_table_name
      REGION_AWS = var.region
    }
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name = "url-shortener-api"
}

resource "aws_api_gateway_resource" "newurl" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "newurl"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.newurl.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.newurl.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_url.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_create" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_resource" "shortid" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{short_id}"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.shortid.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.shortid.id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.retrieve_url.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_retrieve" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrieve_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api" {
  depends_on  = [aws_api_gateway_integration.post, aws_api_gateway_integration.get]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}



# Use existing certificate from ap-southeast-1
data "aws_acm_certificate" "existing_cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}



resource "aws_api_gateway_domain_name" "custom" {
  domain_name              = var.domain_name
  regional_certificate_arn = data.aws_acm_certificate.existing_cert.arn
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "custom" {
  domain_name = aws_api_gateway_domain_name.custom.domain_name
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
}

resource "aws_route53_record" "custom_domain" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.custom.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.custom.regional_zone_id
    evaluate_target_health = false
  }
}
