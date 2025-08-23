terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.4.0"
}

provider "aws" {
  region = "us-east-1" # ACM for CloudFront must be in us-east-1
}

# -------------------------
# S3 Bucket for Website Hosting
# -------------------------
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = var.bucket_name
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

resource "aws_s3_bucket_policy" "portfolio_policy" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.portfolio_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "portfolio_access" {
  bucket                  = aws_s3_bucket.portfolio_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_object" "frontend_files" {
  for_each     = fileset("../frontend", "**/*.*")
  bucket       = aws_s3_bucket.portfolio_bucket.id
  key          = each.value
  source       = "../frontend/${each.value}"
  etag         = filemd5("../frontend/${each.value}")
  content_type = lookup(var.mime_types, regex("\\.[^.]+$", each.value), "text/plain")
}

# -------------------------
# ACM Certificate
# -------------------------
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------
# CloudFront Distribution
# -------------------------
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.portfolio_website.website_endpoint
    origin_id   = "s3-portfolio-origin"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "s3-portfolio-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# -------------------------
# DynamoDB Tables
# -------------------------
resource "aws_dynamodb_table" "contact_form_table" {
  name         = "ContactFormTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "visitor_logs_table" {
  name         = "VisitorLogsTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# -------------------------
# Lambda Functions
# -------------------------
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "contact_form" {
  function_name = "ContactFormHandler"
  runtime       = "python3.9"
  handler       = "handleContactForm.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../lambda/function.zip"
}

resource "aws_lambda_function" "visitor_logger" {
  function_name = "VisitorLogger"
  runtime       = "python3.9"
  handler       = "logVisitorData.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../lambda/visitor.zip"
}

# -------------------------
# API Gateway
# -------------------------
resource "aws_api_gateway_rest_api" "contact_api" {
  name        = "ContactFormAPI"
  description = "API for contact form submission"
}

resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  parent_id   = aws_api_gateway_rest_api.contact_api.root_resource_id
  path_part   = "contact"
}

resource "aws_api_gateway_method" "contact_post" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "contact_integration" {
  rest_api_id             = aws_api_gateway_rest_api.contact_api.id
  resource_id             = aws_api_gateway_resource.contact_resource.id
  http_method             = aws_api_gateway_method.contact_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.contact_form.invoke_arn
}

resource "aws_lambda_permission" "contact_api_permission" {
  statement_id  = "AllowAPIGatewayInvokeContact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form.function_name
  principal     = "apigateway.amazonaws.com"
}

# -------------------------
# CloudWatch Dashboard + Alarm
# -------------------------
resource "aws_cloudwatch_dashboard" "portfolio_dashboard" {
  dashboard_name = "PortfolioDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.portfolio_distribution.id]
          ]
          period = 300
          stat   = "Sum"
          title  = "CloudFront Requests"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_requests_alarm" {
  alarm_name          = "HighCloudFrontRequests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Requests"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  dimensions = {
    DistributionId = aws_cloudfront_distribution.portfolio_distribution.id
  }
}

