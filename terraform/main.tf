provider "aws" {
  region = var.aws_region
}

# ------------------------------
# S3 Bucket for Frontend Hosting
# ------------------------------
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "portfolio_bucket_block" {
  bucket                  = aws_s3_bucket.portfolio_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "portfolio_bucket_policy" {
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

resource "aws_s3_bucket_website_configuration" "portfolio_website" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_object" "frontend_files" {
  for_each = fileset("${path.module}/../frontend", "*")

  bucket       = aws_s3_bucket.portfolio_bucket.id
  key          = each.value
  source       = "${path.module}/../frontend/${each.value}"
  etag         = filemd5("${path.module}/../frontend/${each.value}")
  content_type = lookup(var.mime_types, regex("\\.[^.]+$", each.value), "text/plain")
}

# ------------------------------
# CloudFront for CDN
# ------------------------------
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.portfolio_bucket.id}"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.portfolio_bucket.id}"

    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.acm_certificate_arn
    ssl_support_method   = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# ------------------------------
# DynamoDB for Contact Form Data
# ------------------------------
resource "aws_dynamodb_table" "contact_form_table" {
  name         = "ContactFormData"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ------------------------------
# Lambda Functions
# ------------------------------
resource "aws_lambda_function" "contact_form_handler" {
  function_name = "handleContactForm"
  handler       = "handleContactForm.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "${path.module}/../lambda/function.zip"
}

resource "aws_lambda_function" "visitor_logger" {
  function_name = "logVisitorData"
  handler       = "logVisitorData.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "${path.module}/../lambda/visitor.zip"
}

# ------------------------------
# IAM Role for Lambda
# ------------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

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
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# ------------------------------
# API Gateway
# ------------------------------
resource "aws_api_gateway_rest_api" "portfolio_api" {
  name        = "PortfolioAPI"
  description = "API for contact form and visitor logging"
}

resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  parent_id   = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  path_part   = "contact"
}

resource "aws_api_gateway_method" "contact_method" {
  rest_api_id   = aws_api_gateway_rest_api.portfolio_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "contact_integration" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.contact_form_handler.invoke_arn
}

# Deployment
resource "aws_api_gateway_deployment" "portfolio_api_deployment" {
  depends_on  = [aws_api_gateway_integration.contact_integration]
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
}

# Stage
resource "aws_api_gateway_stage" "portfolio_api_stage" {
  rest_api_id   = aws_api_gateway_rest_api.portfolio_api.id
  deployment_id = aws_api_gateway_deployment.portfolio_api_deployment.id
  stage_name    = "prod"
}

# ------------------------------
# CloudWatch Dashboard
# ------------------------------
resource "aws_cloudwatch_dashboard" "portfolio_dashboard" {
  dashboard_name = "PortfolioDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x    = 0
        y    = 0
        width = 6
        height = 6
        properties = {
          metrics = [
            [ "AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.contact_form_handler.function_name ],
            [ ".", "Errors", ".", "." ],
            [ "AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.portfolio_api.name ],
            [ ".", "5XXError", ".", "." ]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          period = 300
        }
      }
    ]
  })
}

# ------------------------------
# CloudWatch Alarms
# ------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "LambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "This alarm triggers when Lambda errors > 1"
  dimensions = {
    FunctionName = aws_lambda_function.contact_form_handler.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_alarm" {
  alarm_name          = "APIGateway5xxErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "This alarm triggers when API Gateway returns 5XX errors"
  dimensions = {
    ApiName = aws_api_gateway_rest_api.portfolio_api.name
  }
}
