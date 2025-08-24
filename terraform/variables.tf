variable "aws_region" {
  default = "ap-south-1"
}

variable "bucket_name" {
  default = "chaitalidaware.me"
}

variable "domain_name" {
  description = "Your domain name (e.g., chaitalidaware.me)"
  default     = "chaitalidaware.me"
}

variable "frontend_dir" {
  default = "../frontend"
}

variable "lambda_dir" {
  default = "../lambda"
}
