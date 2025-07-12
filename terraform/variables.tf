variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-southeast-1"
}

variable "dynamodb_table" {
  description = "The name of the DynamoDB table to use for storing URLs"
  type        = string
  default     = "url-shortener-table" 
  
}