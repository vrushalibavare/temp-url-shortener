variable "domain_name" {
  default = "vrushurl.sctp-sandbox.com"
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for sctp-sandbox.com"
  default     = "Z00541411T1NGPV97B5C0" # Replace with your actual zone ID
}

variable "dynamodb_table_name" {
  default = "short_urls"
}

variable "region" {
  default = "ap-southeast-1"
}
