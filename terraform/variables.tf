variable "bucket_name" {
  description = "S3 bucket name for the portfolio"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for the portfolio"
  type        = string
}

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "us_east_region" {
  description = "AWS region for ACM certificate (must be us-east-1)"
  type        = string
  default     = "us-east-1"
}
