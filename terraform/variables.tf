variable "aws_region" {
  default = "ap-south-1"
}

variable "bucket_name" {
  description = "S3 bucket name for the website"
}

variable "domain_name" {
  description = "Custom domain name (e.g., chaitalidaware.me)"
}

variable "lambda_role_name" {
  default = "portfolio-lambda-role"
}
