variable "aws_region" {
  default = "ap-south-1"
}

variable "domain_name" {
  description = "Your custom domain from Namecheap"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for static website"
  type        = string
}

variable "lambda_contact_name" {
  default = "handleContactForm"
}

variable "lambda_visitor_name" {
  default = "logVisitorData"
}

variable "dynamodb_contact_table" {
  default = "ContactFormSubmissions"
}

variable "dynamodb_visitor_table" {
  default = "VisitorLogs"
}
