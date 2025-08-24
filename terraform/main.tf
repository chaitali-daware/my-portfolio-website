locals {
  tags = {
    Project = var.project
    Stack   = "portfolio"
  }
}

# ----- DynamoDB tables -----
resource "aws_dynamodb_table" "contact" {
  name         = "${var.project}-contact"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}

resource "aws_dynamodb_table" "visitor" {
  name         = "${var.project}-visitor"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}

# ----- Lambda packages (zip from source) -----
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

# ----- IAM for Lambdas -----
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "lambda_policy_doc" {
  statement {
    sid     = "DynamoAccess"
    actions = ["dynamodb:PutItem"]
    resources = [
      aws_dynamodb_table.contact.arn,
      aws_dynamodb_table.visitor.arn
    ]
  }

  statement {
    sid     = "CloudWatchMetrics"
    actions = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:::*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${var.project}-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ----- Lambda functions -----
resource "aws_lambda_function" "contact" {
  function_name    = "${var.project}-handle-contact"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handleContactForm.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.contact_zip.output_path
  source_code_hash = data.archive_file.contact_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      CONTACT_TABLE = aws_dynamodb_table.contact.name
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "visitor" {
  function_name    = "${var.project}-log-visitor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "logVisitorData.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.visitor_zip.output_path
  source_code_hash = data.archive_file.visitor_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      VISITOR_TABLE = aws_dynamodb_table.visitor.name
    }
  }

  tags = local.tags
}

# ----- API Gateway HTTP API -----
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["*"]
  }

  tags = local.tags
}

# Integrations
resource "aws_apigatewayv2_integration" "contact_integ" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "visitor_integ" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.visitor.invoke_arn
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

# Stage (auto-deploy)
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

# Permissions for API to call Lambda
resource "aws_lambda_permission" "apigw_contact" {
  statement_id  = "AllowAPIGatewayInvokeContact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/POST/contact"
}

resource "aws_lambda_permission" "apigw_visitor" {
  statement_id  = "AllowAPIGatewayInvokeVisitor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/POST/visitor"
}

# ----- ACM Certificate for Custom Domain -----
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = local.tags
}

# Output ACM Validation Info (for Namecheap DNS)
output "acm_validation_cname" {
  value = aws_acm_certificate.cert.domain_validation_options
}

# ----- S3 Bucket (private) -----
resource "aws_s3_bucket" "site" {
  bucket        = var.bucket_name
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----- CloudFront with ACM -----
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project}-oac"
  description                       = "OAC for private S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  comment             = "${var.project} portfolio"
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

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
    acm_certificate_arn     = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  aliases = [var.domain_name]
  tags    = local.tags
}

# Bucket policy allowing only this CloudFront distribution
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid = "AllowCloudFrontServicePrincipalReadOnly"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site_policy" {
  bucket     = aws_s3_bucket.site.id
  policy     = data.aws_iam_policy_document.bucket_policy.json
  depends_on = [aws_cloudfront_distribution.cdn]
}

# ----- CloudWatch Dashboard & Alarms -----
resource "aws_cloudwatch_dashboard" "dash" {
  dashboard_name = "${var.project}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Page Visits (by page)"
          metrics = [["Portfolio/Metrics", "PageVisits", "Page", "/"]]
          period  = 300
          stat    = "Sum"
          region  = var.aws_region
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Contact Submissions"
          metrics = [["Portfolio/Metrics", "ContactSubmissions", "Page", "Contact"]]
          period  = 300
          stat    = "Sum"
          region  = var.aws_region
          view    = "timeSeries"
        }
      }
    ]
  })
}

resource "aws_sns_topic" "alarms" {
  name = "${var.project}-alarms"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.alarm_email) > 0 ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Any Lambda errors > 0 in last 5 minutes"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

# ----- Helpful tags -----
resource "aws_cloudwatch_log_group" "contact_lg" {
  name              = "/aws/lambda/${aws_lambda_function.contact.function_name}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "visitor_lg" {
  name              = "/aws/lambda/${aws_lambda_function.visitor.function_name}"
  retention_in_days = 14
  tags              = local.tags
}
