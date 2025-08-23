# main.tf
provider "aws" {
  region = "ap-south-1"
}

# ---------------------------
# S3 Bucket for static site
# ---------------------------
resource "aws_s3_bucket" "website" {
  bucket         = var.s3_bucket_name
  acl            = "public-read"
  force_destroy  = true
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.website.arn}/*"
    }]
  })
}

# ---------------------------
# ACM Certificate
# ---------------------------
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------
# DynamoDB Tables
# ---------------------------
resource "aws_dynamodb_table" "contact" {
  name         = var.contact_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "visitor" {
  name         = var.visitor_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------------------
# IAM Role for Lambda
# ---------------------------
resource "aws_iam_role" "lambda_role" {
  name = "portfolio_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

# ---------------------------
# Lambda Functions
# ---------------------------
resource "aws_lambda_function" "handle_contact" {
  filename         = "terraform/contact.zip"
  function_name    = "handleContactForm"
  handler          = "handleContactForm.lambda_handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_role.arn
  environment {
    variables = {
      CONTACT_TABLE = aws_dynamodb_table.contact.name
    }
  }
}

resource "aws_lambda_function" "log_visitor" {
  filename         = "terraform/visitor.zip"
  function_name    = "logVisitorData"
  handler          = "logVisitorData.lambda_handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_role.arn
  environment {
    variables = {
      VISITOR_TABLE = aws_dynamodb_table.visitor.name
    }
  }
}

# ---------------------------
# API Gateway HTTP APIs
# ---------------------------
resource "aws_apigatewayv2_api" "contact_api" {
  name          = "ContactAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "contact_integration" {
  api_id           = aws_apigatewayv2_api.contact_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.handle_contact.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact_route" {
  api_id    = aws_apigatewayv2_api.contact_api.id
  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact_integration.id}"
}

resource "aws_lambda_permission" "allow_contact_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handle_contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "VisitorAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "visitor_integration" {
  api_id           = aws_apigatewayv2_api.visitor_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.log_visitor.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visitor_route" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "POST /visitor"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_integration.id}"
}

resource "aws_lambda_permission" "allow_visitor_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_visitor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}

# ---------------------------
# CloudFront Distribution
# ---------------------------
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = var.cloudfront_price_class
}
