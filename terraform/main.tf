provider "aws" {
  region = var.aws_region
}

# -------------------------
# S3 Bucket
# -------------------------
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
}

# Block public access disabled (required to allow public policy)
resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public read policy
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# S3 Website configuration
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.id

  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

# Upload frontend files
resource "aws_s3_object" "website_files" {
  for_each = { for file in fileset("${path.module}/../frontend", "**/*") : file => file }

  bucket = aws_s3_bucket.website.id
  key    = each.value
  source = "${path.module}/../frontend/${each.value}"
}

# -------------------------
# ACM Certificate
# -------------------------
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
}

output "acm_cert_arn" {
  value = aws_acm_certificate.cert.arn
}

# -------------------------
# DynamoDB Tables
# -------------------------
resource "aws_dynamodb_table" "contact_form" {
  name           = var.contact_form_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "visitor" {
  name           = var.visitor_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# -------------------------
# Lambda for contact form
# -------------------------
resource "aws_lambda_function" "handle_contact_form" {
  filename         = "../lambda/function.zip"
  function_name    = "handleContactForm"
  handler          = "handleContactForm.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "log_visitor" {
  filename         = "../lambda/visitor.zip"
  function_name    = "logVisitorData"
  handler          = "logVisitorData.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec.arn
}

# Lambda IAM role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# -------------------------
# CloudWatch Dashboard
# -------------------------
resource "aws_cloudwatch_dashboard" "dashboard" {
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
          metrics = [["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.handle_contact_form.function_name]]
          period  = 300
          stat    = "Sum"
        }
      }
    ]
  })
}

# -------------------------
# CloudFront Distribution
# -------------------------
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${var.bucket_name}"

    s3_origin_config {}
  }

  default_cache_behavior {
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
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

  aliases = [var.domain_name]
}
