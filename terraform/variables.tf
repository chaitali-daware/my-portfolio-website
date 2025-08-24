variable "aws_region" {
  default = "ap-south-1"
}

variable "bucket_name" {
  default = "chaitalidaware.me"
}

variable "domain_name" {
  description = "Your custom domain (Namecheap)"
}

variable "contact_form_table" {
  default = "ContactFormSubmissions"
}

variable "visitor_table" {
  default = "VisitorLogs"
}
