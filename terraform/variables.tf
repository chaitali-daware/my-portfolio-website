variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "local_website_path" {
  description = "Local path of website files (HTML, CSS, JS)"
  type        = string
  default     = "./frontend"
}
