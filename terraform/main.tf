terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# ======================
# S3 Bucket for Website
# ======================
resource "aws_s3_bucket" "website" {
  bucket = var.s3_bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    Name = "PortfolioWebsiteBucket"
  }
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# ======================
# ACM Certificate
# ======================
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "PortfolioWebsiteCert"
  }
}

resource "aws_route53_record" "acm_validation" {
  # This will be manually added in Namecheap
  count   = length(aws_acm_certificate.cert.domain_validation_options)
  name    = aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_type
  records = [aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

# ======================
# CloudFront Distribution
# ======================
resource "aws_cloudfront_distribution" "cdn" {
  depends_on = [aws_acm_certificate_validation.cert_validation]

  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-Website"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Website"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.cert.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  aliases = [var.domain_name]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "PortfolioCloudFront"
  }
}

# ======================
# DynamoDB Tables
# ======================
resource "aws_dynamodb_table" "contact" {
  name         = var.dynamodb_contact_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "visitor" {
  name         = var.dynamodb_visitor_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ======================
# IAM Role for Lambda
# ======================
resource "aws_iam_role" "lambda_role" {
  name = "lambda_basic_execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "dynamodb_access" {
  name = "LambdaDynamoPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:PutItem",
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ]
        Resource = [
          aws_dynamodb_table.contact.arn,
          aws_dynamodb_table.visitor.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# ======================
# Lambda Functions
# ======================
resource "aws_lambda_function" "contact" {
  function_name = var.lambda_contact_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "contact.lambda_handler"
  runtime       = "python3.11"

  filename = "lambda/contact.zip"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.contact.name
    }
  }
}

resource "aws_lambda_function" "visitor" {
  function_name = var.lambda_visitor_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "visitor.lambda_handler"
  runtime       = "python3.11"

  filename = "lambda/visitor.zip"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor.name
    }
  }
}

# ======================
# API Gateway HTTP API
# ======================
resource "aws_apigatewayv2_api" "contact_api" {
  name          = "ContactAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "contact_integration" {
  api_id           = aws_apigatewayv2_api.contact_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.contact.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact_route" {
  api_id    = aws_apigatewayv2_api.contact_api.id
  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact_integration.id}"
}

resource "aws_lambda_permission" "contact_apigw" {
  statement_id  = "AllowAPIGatewayInvokeContact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_api.execution_arn}/*/*"
}

# Repeat similarly for Visitor API
resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "VisitorAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "visitor_integration" {
  api_id           = aws_apigatewayv2_api.visitor_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visitor_route" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "POST /visitor"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_integration.id}"
}

resource "aws_lambda_permission" "visitor_apigw" {
  statement_id  = "AllowAPIGatewayInvokeVisitor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}

# ======================
# CloudWatch Dashboard
# ======================
resource "aws_cloudwatch_dashboard" "portfolio_dashboard" {
  dashboard_name = "PortfolioDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.contact.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.contact.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.visitor.function_name]
          ]
          view = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}

# ======================
# CloudWatch Alarms
# ======================
resource "aws_cloudwatch_metric_alarm" "contact_errors" {
  alarm_name          = "ContactLambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when contact Lambda function has errors"
  dimensions = {
    FunctionName = aws_lambda_function.contact.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "visitor_errors" {
  alarm_name          = "VisitorLambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when visitor Lambda function has errors"
  dimensions = {
    FunctionName = aws_lambda_function.visitor.function_name
  }
}
