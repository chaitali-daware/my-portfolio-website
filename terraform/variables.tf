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

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for enabling HTTPS with CloudFront (must be in us-east-1)"
  type        = string
  default     = "arn:aws:acm:us-east-1:058264155367:certificate/a43ec253-95bb-4ea2-bdb3-362cb6154244"
}
