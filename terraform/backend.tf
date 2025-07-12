terraform {
  backend "s3" {
    bucket         = "vrush-tfstate-bucket"
    key            = "tf-url-shortener-tfstate"
    region         = "ap-southeast-1"
  }
}