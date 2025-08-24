variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "domain_name" {
  description = "Your custom domain name"
  type        = string
}
