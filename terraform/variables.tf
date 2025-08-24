variable "aws_region" {
  default = "ap-south-1"
}

variable "bucket_name" {
  description = "S3 bucket name"
  default     = "chaitalidaware.me"
}

variable "domain_name" {
  description = "Your custom domain"
  default     = "chaitalidaware.me"
}

variable "frontend_folder" {
  description = "Path to frontend folder"
  default     = "../frontend"
}

variable "lambda_folder" {
  description = "Path to lambda folder"
  default     = "../lambda"
}
