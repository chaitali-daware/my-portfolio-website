variable "bucket_name" {
  description = "S3 bucket name for the portfolio"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for the portfolio"
  type        = string
}

variable "mime_types" {
  description = "Mapping of file extensions to MIME types for S3 uploads"
  type        = map(string)
  default = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".json" = "application/json"
  }
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}
