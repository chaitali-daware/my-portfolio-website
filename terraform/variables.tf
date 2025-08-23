variable "bucket_name" {
  description = "S3 bucket name for the portfolio"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for the portfolio"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  default     = "ap-south-1"
}

variable "acm_region" {
  description = "Region for ACM certificate (must be us-east-1 for CloudFront)"
  default     = "us-east-1"
}
