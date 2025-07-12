data aws_availability_zones {
  state = "available"
  filter {
    name   = "region-name"
    values = [var.region]
    
  }
} 

data aws_iam_policy_document lambda_ddb_policy  {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Scan"
    ]
    resources = [aws_dynamodb_table.url_table.arn]
  }
}

data "archive_file" "lambda_createurl_zip" {
  type        = "zip"
  source_file  = "${path.module}/lambda/create-url/app.py"
  output_path = "${path.module}/lambda/create-url/app.zip"
}

data "archive_file" "lambda_retrieveurl_zip" {
  type        = "zip"
  source_file  = "${path.module}/lambda/retrieve-url/app.py"
  output_path = "${path.module}/lambda/retrieve-url/app.zip"
}