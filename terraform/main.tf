terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" { region = var.aws_region }
# us-east-1 provider for ACM/CloudFront cert
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

# ---------- S3 for frontend ----------
resource "aws_s3_bucket" "site" {
  bucket = "${var.project_name}-site-${random_id.rand.hex}"
  force_destroy = true
}
resource "random_id" "rand" { byte_length = 4 }

resource "aws_s3_bucket_ownership_controls" "own" {
  bucket = aws_s3_bucket.site.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_public_access_block" "pab" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Allow CloudFront to read S3
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"
    principals { type = "Service", identifiers = ["cloudfront.amazonaws.com"] }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# ---------- DynamoDB ----------
resource "aws_dynamodb_table" "contact" {
  name         = "${var.project_name}-ContactFormSubmissions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"
  attribute { name = "pk" type = "S" }
  attribute { name = "sk" type = "S" }
}

resource "aws_dynamodb_table" "visitors" {
  name         = "${var.project_name}-VisitorLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"
  attribute { name = "pk" type = "S" }
  attribute { name = "sk" type = "S" }
}

# ---------- IAM for Lambdas ----------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
  }
}
resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.contact.arn, aws_dynamodb_table.visitors.arn]
  }
  statement {
    actions   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
  }
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}
resource "aws_iam_policy" "lambda" {
  name   = "${var.project_name}-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}
resource "aws_iam_role_policy_attachment" "att" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

# ---------- Package Lambdas ----------
data "archive_file" "contact_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handleContactForm.py"
  output_path = "${path.module}/../lambda/handleContactForm.zip"
}
data "archive_file" "visitor_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/logVisitorData.py"
  output_path = "${path.module}/../lambda/logVisitorData.zip"
}

resource "aws_lambda_function" "contact" {
  function_name = "${var.project_name}-handleContactForm"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.11"
  handler       = "handleContactForm.handler"
  filename      = data.archive_file.contact_zip.output_path
  environment { variables = { CONTACT_TABLE = aws_dynamodb_table.contact.name } }
  depends_on = [aws_iam_role_policy_attachment.att]
}

resource "aws_lambda_function" "visitor" {
  function_name = "${var.project_name}-logVisitorData"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.11"
  handler       = "logVisitorData.handler"
  filename      = data.archive_file.visitor_zip.output_path
  environment { variables = { VISITOR_TABLE = aws_dynamodb_table.visitors.name } }
  depends_on = [aws_iam_role_policy_attachment.att]
}

# ---------- API Gateway (HTTP API) ----------
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["OPTIONS", "POST"]
    allow_origins = ["*"]
  }
}
# Integrations
resource "aws_apigatewayv2_integration" "contact_integ" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.contact.invoke_arn
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_integration" "visitor_integ" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor.invoke_arn
  payload_format_version = "2.0"
}
# Routes
resource "aws_apigatewayv2_route" "contact_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact_integ.id}"
}
resource "aws_apigatewayv2_route" "visitor_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /visitor"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_integ.id}"
}
# Stage
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "prod"
  auto_deploy = true
}

# Permissions for API to call Lambda
resource "aws_lambda_permission" "allow_contact" {
  statement_id  = "AllowAPIGatewayInvokeContact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*/contact"
}
resource "aws_lambda_permission" "allow_visitor" {
  statement_id  = "AllowAPIGatewayInvokeVisitor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*/visitor"
}

# ---------- CloudWatch: Alarms & Dashboard ----------
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-LambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions          = {}
  alarm_description   = "Any Lambda errors in 5 mins"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_dashboard" "dash" {
  dashboard_name = "Portfolio-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        "type":"metric","width":12,"height":6,"x":0,"y":0,
        "properties":{
          "title":"Contact Lambda Invocations",
          "metrics":[["AWS/Lambda","Invocations","FunctionName",aws_lambda_function.contact.function_name]],
          "period":300,"stat":"Sum","region":var.aws_region
        }
      },
      {
        "type":"metric","width":12,"height":6,"x":12,"y":0,
        "properties":{
          "title":"Visitor Lambda Invocations",
          "metrics":[["AWS/Lambda","Invocations","FunctionName",aws_lambda_function.visitor.function_name]],
          "period":300,"stat":"Sum","region":var.aws_region
        }
      },
      {
        "type":"metric","width":24,"height":6,"x":0,"y":6,
        "properties":{
          "title":"Custom Metric - Page Visits (Portfolio/PageVisit)",
          "metrics":[["Portfolio","PageVisit","Page","/"]],
          "period":300,"stat":"Sum","region":var.aws_region
        }
      }
    ]
  })
}

# ---------- ACM (us-east-1) for CloudFront ----------
resource "aws_acm_certificate" "cert" {
  provider          = aws.use1
  domain_name       = var.domain_name
  validation_method = "DNS"
  subject_alternative_names = [var.alt_domain]
  lifecycle { create_before_destroy = true }
}

# Wait for manual DNS validation (Namecheap)
resource "aws_acm_certificate_validation" "certval" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.resource_record_name]
  # Terraform will poll until validation is successful AFTER you create CNAMEs in Namecheap
}

# ---------- CloudFront ----------
resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET","HEAD","OPTIONS"]
    cached_methods         = ["GET","HEAD"]
    compress               = true
    forwarded_values { query_string = false cookies { forward = "none" } }
  }

  price_class = "PriceClass_100"

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate_validation.certval.certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.certval]
}

# ---------- Helpful locals for CI ----------
locals {
  visitor_api_url = "${aws_apigatewayv2_api.api.api_endpoint}/visitor"
  contact_api_url = "${aws_apigatewayv2_api.api.api_endpoint}/contact"
}
