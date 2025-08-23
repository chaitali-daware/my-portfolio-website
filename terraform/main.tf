terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

# Default provider (ap-south-1)
provider "aws" {
  region = "ap-south-1"
}

# For ACM (must be in us-east-1)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

# ---------------------------
# S3 bucket for frontend
# ---------------------------
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "portfolio_website" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

# CloudFront OAI
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for portfolio CloudFront"
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly",
        Effect = "Allow",
        Principal = { AWS = aws_cloudfront_origin_access_identity.oai.iam_arn },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.portfolio_bucket.arn}/*"
      }
    ]
  })
}

# ---------------------------
# DynamoDB tables
# ---------------------------
resource "aws_dynamodb_table" "contact_form_table" {
  name         = "ContactFormSubmissions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute { name = "id"; type = "S" }
}

resource "aws_dynamodb_table" "visitor_logs_table" {
  name         = "VisitorLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute { name = "id"; type = "S" }
}

# ---------------------------
# IAM Role & Policy for Lambda
# ---------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-dynamodb-cloudwatch-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Scan"],
        Resource = [
          aws_dynamodb_table.contact_form_table.arn,
          aws_dynamodb_table.visitor_logs_table.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = ["cloudwatch:PutMetricData"],
        Resource = "*"
      }
    ]
  })
}

# ---------------------------
# Lambda Functions (zipped by CI)
# ---------------------------
resource "aws_lambda_function" "contact_form" {
  function_name    = "handleContactForm"
  handler          = "handleContactForm.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec.arn
  filename         = "${path.module}/function.zip"
  source_code_hash = filebase64sha256("${path.module}/function.zip")
  environment { variables = { CONTACT_TABLE = aws_dynamodb_table.contact_form_table.name } }
  depends_on = [aws_iam_role_policy.lambda_policy]
}

resource "aws_lambda_function" "log_visitor" {
  function_name    = "logVisitorData"
  handler          = "logVisitorData.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec.arn
  filename         = "${path.module}/visitor.zip"
  source_code_hash = filebase64sha256("${path.module}/visitor.zip")
  environment { variables = { VISITOR_TABLE = aws_dynamodb_table.visitor_logs_table.name } }
  depends_on = [aws_iam_role_policy.lambda_policy]
}

# ---------------------------
# API Gateway (HTTP API) - Contact
# ---------------------------
resource "aws_apigatewayv2_api" "contact_form_api" {
  name          = "ContactFormAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "contact_form_integration" {
  api_id                 = aws_apigatewayv2_api.contact_form_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact_form.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact_form_route" {
  api_id    = aws_apigatewayv2_api.contact_form_api.id
  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact_form_integration.id}"
}

resource "aws_apigatewayv2_stage" "contact_form_stage" {
  api_id      = aws_apigatewayv2_api.contact_form_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "contact_form_permission" {
  statement_id  = "AllowContactFormAPI"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_form_api.execution_arn}/*/*"
}

# ---------------------------
# API Gateway (HTTP API) - Visitor
# ---------------------------
resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "VisitorTrackingAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "visitor_integration" {
  api_id                 = aws_apigatewayv2_api.visitor_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.log_visitor.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visitor_route" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "POST /visit"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_integration.id}"
}

resource "aws_apigatewayv2_stage" "visitor_stage" {
  api_id      = aws_apigatewayv2_api.visitor_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "visitor_permission" {
  statement_id  = "AllowVisitorAPI"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_visitor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}

# ---------------------------
# ACM Certificate in us-east-1 (for CloudFront)
# ---------------------------
resource "aws_acm_certificate" "cert" {
  provider          = aws.use1
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}

# Output-friendly mapping for validation records will be in output.tf

# Null resource to pause until ACM is validated (local-exec)
resource "null_resource" "wait_for_acm" {
  triggers = { cert_arn = aws_acm_certificate.cert.arn }

  provisioner "local-exec" {
    command = <<EOT
echo "Waiting for ACM certificate to be issued..."
aws acm wait certificate-validated --certificate-arn ${aws_acm_certificate.cert.arn} --region us-east-1
echo "ACM certificate validated!"
EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# ---------------------------
# CloudFront Distribution
# ---------------------------
resource "aws_cloudfront_distribution" "portfolio_distribution" {
  depends_on = [null_resource.wait_for_acm]

  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3Origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn     = aws_acm_certificate.cert.arn
    ssl_support_method      = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"

  tags = { Name = "PortfolioCloudFront" }
}

# ---------------------------
# CloudWatch Dashboard & Alarms (basic)
# ---------------------------
resource "aws_cloudwatch_dashboard" "portfolio_dashboard" {
  dashboard_name = "PortfolioDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 24, height = 6,
        properties = {
          metrics = [
            ["Portfolio/Metrics", "PageVisits", "Page", "index.html"],
            ["Portfolio/Metrics", "ContactSubmissions"]
          ],
          period = 300,
          stat = "Sum",
          region = "ap-south-1",
          title = "Portfolio Metrics"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "contact_lambda_error_alarm" {
  alarm_name          = "ContactLambdaErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when contact lambda has errors"
  dimensions = { FunctionName = aws_lambda_function.contact_form.function_name }
}

resource "aws_cloudwatch_metric_alarm" "visitor_lambda_error_alarm" {
  alarm_name          = "VisitorLambdaErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when visitor lambda has errors"
  dimensions = { FunctionName = aws_lambda_function.log_visitor.function_name }
}
