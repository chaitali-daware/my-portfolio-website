terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = ">= 5.30" }
    archive = { source = "hashicorp/archive", version = ">= 2.4.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "project" {
  description = "Project name used for tagging/naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all regional services"
  type        = string
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for the site"
  type        = string
}

variable "alarm_email" {
  description = "Optional email address to receive CloudWatch alarm notifications"
  type        = string
  default     = ""
}
