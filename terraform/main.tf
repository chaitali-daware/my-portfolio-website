provider "aws" {
  region = var.region
}

# S3 Bucket for Portfolio Hosting
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = var.bucket_name
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "portfolio_website" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

# Allow public read access for files
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.portfolio_bucket.arn}/*"
      }
    ]
  })
}

# Upload frontend files (HTML, CSS, JS)
resource "aws_s3_bucket_object" "frontend_files" {
  for_each     = fileset("${path.module}/../frontend", "**/*.*")
  bucket       = aws_s3_bucket.portfolio_bucket.id
  key          = each.value
  source       = "${path.module}/../frontend/${each.value}"
  etag         = filemd5("${path.module}/../frontend/${each.value}")
  content_type = lookup(var.mime_types, regex("\\.[^.]+$", each.value), "text/plain")
}

# ACM Certificate (in us-east-1 for CloudFront)
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "s3-origin"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }
}

# Lambda for Contact Form
resource "aws_lambda_function" "contact_form" {
  function_name = "contact-form-handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  filename      = "${path.module}/lambda/contact_form.zip"
}

# Lambda for Visitor Counter
resource "aws_lambda_function" "visitor_counter" {
  function_name = "visitor-counter-handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  filename      = "${path.module}/lambda/visitor_counter.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-basic-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway for Contact Form and Visitor Counter
resource "aws_api_gateway_rest_api" "portfolio_api" {
  name        = "PortfolioAPI"
  description = "API for contact form and visitor counter"
}

resource "aws_api_gateway_resource" "contact_form_resource" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  parent_id   = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  path_part   = "contact"
}

resource "aws_api_gateway_method" "contact_form_method" {
  rest_api_id   = aws_api_gateway_rest_api.portfolio_api.id
  resource_id   = aws_api_gateway_resource.contact_form_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "contact_form_integration" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  resource_id = aws_api_gateway_resource.contact_form_resource.id
  http_method = aws_api_gateway_method.contact_form_method.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.contact_form.invoke_arn
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "portfolio_api_deployment" {
  depends_on  = [aws_api_gateway_integration.contact_form_integration]
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  stage_name  = "prod"
}

# Permissions for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.portfolio_api.execution_arn}/*/*"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/contact-form-handler"
  retention_in_days = 14
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "portfolio_dashboard" {
  dashboard_name = "PortfolioDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.contact_form.function_name]]
          title   = "Lambda Invocations"
        }
      }
    ]
  })
}

# CloudWatch Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "LambdaErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm if Lambda errors > 1"
  dimensions = {
    FunctionName = aws_lambda_function.contact_form.function_name
  }
}
