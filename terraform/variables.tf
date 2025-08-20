variable "bucket_name" {
  description = "Name of the S3 bucket used to host the portfolio website"
  type        = string
  default     = "chaitalidaware.me"
}

variable "domain_name" {
  description = "Your custom domain name used with CloudFront and HTTPS"
  type        = string
  default     = "chaitalidaware.me"
}

