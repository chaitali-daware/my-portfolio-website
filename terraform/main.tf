provider "aws" {
  region = "ap-south-1"
}

# ---------------------------
# S3 Bucket for Frontend
# ---------------------------
resource "aws_s3_bucket" "portfolio_bucket" {
  bucket         = var.bucket_name
  force_destroy  = true
}

# Enforce Ownership Control
resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Website Configuration (still needed for index.html fallback)
resource "aws_s3_bucket_website_configuration" "portfolio_website" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  index_document {
    suffix = "index.html"
  }
}

# ---------------------------
# IAM Role and Policies for Lambda
# ---------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement: [{
      Action:    "sts:AssumeRole",
      Principal: { Service: "lambda.amazonaws.com" },
      Effect:    "Allow",
      Sid:       ""
    }]
  })
}

# Attach DynamoDB permissions to Lambda
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan"
        ],
        Resource: [
          aws_dynamodb_table.contact_form_table.arn,
          aws_dynamodb_table.visitor_logs_table.arn
        ]
      },
      {
        Effect: "Allow",
        Action: [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource: "*"
      }
    ]
  })
}

# ---------------------------
# DynamoDB Tables
# ---------------------------
resource "aws_dynamodb_table" "contact_form_table" {
  name         = "ContactFormSubmissions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "visitor_logs_table" {
  name         = "VisitorLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------------------
# Lambda Functions
# ---------------------------
resource "aws_lambda_function" "contact_form" {
  function_name    = "handleContactForm"
  handler          = "handleContactForm.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec.arn
  filename         = "${path.module}/../lambda/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/function.zip")
  depends_on       = [aws_iam_role.lambda_exec, aws_iam_role_policy.lambda_dynamodb]
}

resource "aws_lambda_function" "log_visitor" {
  function_name    = "logVisitorData"
  handler          = "logVisitorData.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec.arn
  filename         = "${path.module}/../lambda/visitor.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/visitor.zip")
  depends_on       = [aws_iam_role.lambda_exec, aws_iam_role_policy.lambda_dynamodb]
}

# ---------------------------
# API Gateway - Contact Form
# ---------------------------
resource "aws_apigatewayv2_api" "contact_form_api" {
  name          = "ContactFormAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "contact_form_integration" {
  api_id                = aws_apigatewayv2_api.contact_form_api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.contact_form.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact_form_route" {
  api_id    = aws_apigatewayv2_api.contact_form_api.id
  route_key = "POST /submit"
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
# API Gateway - Visitor Tracking
# ---------------------------
resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "VisitorTrackingAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "visitor_integration" {
  api_id                = aws_apigatewayv2_api.visitor_api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.log_visitor.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visitor_route" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "GET /track"
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
# CloudFront + OAI
# ---------------------------
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for portfolio CloudFront"
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        },
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.portfolio_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "portfolio_distribution" {
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

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  # Use ACM if custom domain, else CloudFront default
  viewer_certificate {
    acm_certificate_arn = var.acm_certificate_arn
    ssl_support_method  = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"

  tags = {
    Name = "PortfolioCloudFront"
  }
}
