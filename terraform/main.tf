provider "aws" {
  region = "ap-south-1" # or your preferred region
}

# S3 bucket for static website
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = var.bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

# Upload static files to S3
resource "aws_s3_bucket_object" "frontend_files" {
  for_each = fileset("../frontend", "**/*")

  bucket       = aws_s3_bucket.portfolio_bucket.bucket
  key          = each.value
  source       = "../frontend/${each.value}"
  content_type = lookup(var.mime_types, regex("\\.[^.]+$", each.value), "text/plain")
  acl          = "public-read"
}

# CloudFront distribution for HTTPS
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3-${var.bucket_name}"
  }

  enabled             = true
  default_root_object = "index.html"

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method   = "sni-only"
  }
}

# ACM certificate in us-east-1 (mandatory for CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"
}

# DynamoDB for contact form
resource "aws_dynamodb_table" "contact_form_table" {
  name         = "contact-form"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# DynamoDB for visitor logs
resource "aws_dynamodb_table" "visitor_table" {
  name         = "visitor-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda for contact form
resource "aws_lambda_function" "contact_form_lambda" {
  filename         = "../lambda/function.zip"
  function_name    = "contactFormHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handleContactForm.lambda_handler"
  runtime          = "python3.9"
}

# Lambda for visitor logs
resource "aws_lambda_function" "visitor_lambda" {
  filename         = "../lambda/visitor.zip"
  function_name    = "visitorHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "logVisitorData.lambda_handler"
  runtime          = "python3.9"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"
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

# Attach policies for Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway for contact form
resource "aws_apigatewayv2_api" "contact_form_api" {
  name          = "ContactFormAPI"
  protocol_type = "HTTP"
}

# API Gateway for visitor logs
resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "VisitorAPI"
  protocol_type = "HTTP"
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "portfolio_dashboard" {
  dashboard_name = "PortfolioDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x    = 0
        y    = 0
        width = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.contact_form_lambda.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.visitor_lambda.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = "ap-south-1"
          title  = "Lambda Invocations"
        }
      }
    ]
  })
}
