resource "aws_dynamodb_table" "url_table" {
  name           = var.dynamodb_table
  hash_key       = "short_id"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "short_id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-url-shortener-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_lambda" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource aws_iam_role_policy_attachment "lambda_ddb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy_document.lambda_ddb_policy.json
} 

resource "aws_lambda_function" "create_url" {
  function_name = "create-url-lambda"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_createurl_zip.output_path
  timeout       = 10
  environment {
    variables = {
      APP_URL     = "https://${var.domain_name}/"
      MIN_CHAR    = "12"
      MAX_CHAR    = "16"
      REGION_AWS  = var.region
      DB_NAME     = var.dynamodb_table
    }
  }
  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_function" "retrieve_url" {
  function_name = "retrieve-url-lambda"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_retrieveurl_zip.output_path
  timeout       = 10
  environment {
    variables = {
      REGION_AWS = var.region
      DB_NAME    = var.dynamodb_table
    }
  }
  tracing_config {
    mode = "Active"
  }
}