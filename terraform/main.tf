
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# ----------------------------
# S3 Bucket for Portfolio
# ----------------------------
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = var.bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    Name = "PortfolioBucket"
  }
}

resource "aws_s3_bucket_policy" "portfolio_policy" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = ["${aws_s3_bucket.portfolio_bucket.arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "portfolio_website" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

# ----------------------------
# ACM Certificate (us-east-1)
# ----------------------------
resource "aws_acm_certificate" "cert" {
  provider          = aws.us-east-1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Output DNS validation info for Namecheap
output "acm_validation_records" {
  description = "Add these CNAME records to Namecheap DNS"
  value       = aws_acm_certificate.cert.domain_validation_options
}

# ----------------------------
# CloudFront Distribution
# ----------------------------
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3-Portfolio"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Portfolio distribution"
  default_root_object = "index.html"

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Portfolio"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.cert.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"
}

# ----------------------------
# DynamoDB Table for Logging
# ----------------------------
resource "aws_dynamodb_table" "visitor_table" {
  name           = "VisitorLog"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "VisitorLog"
  }
}

resource "aws_dynamodb_table" "contact_form_table" {
  name           = "ContactForm"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "ContactForm"
  }
}

# ----------------------------
# Lambda Functions
# ----------------------------
resource "aws_lambda_function" "contact_lambda" {
  function_name    = "ContactFormHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handleContactForm.lambda_handler"
  runtime          = "python3.11"
  filename         = "../lambda/function.zip"
}

resource "aws_lambda_function" "visitor_lambda" {
  function_name    = "VisitorLogger"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "logVisitorData.lambda_handler"
  runtime          = "python3.11"
  filename         = "../lambda/visitor.zip"
}

# ----------------------------
# IAM Role for Lambda
# ----------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# ----------------------------
# API Gateway for Lambda
# ----------------------------
resource "aws_apigatewayv2_api" "contact_form_api" {
  name          = "ContactFormAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "VisitorAPI"
  protocol_type = "HTTP"
}

output "bucket_name" {
  value = aws_s3_bucket.portfolio_bucket.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.portfolio_distribution.domain_name
}

output "contact_form_api_url" {
  value = "${aws_apigatewayv2_api.contact_form_api.api_endpoint}/contact"
}

output "visitor_api_url" {
  value = "${aws_apigatewayv2_api.visitor_api.api_endpoint}/visit"
}
