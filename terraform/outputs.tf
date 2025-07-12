output "bucket_name" {
  value = aws_s3_bucket.portfolio_bucket.bucket
}


output "cloudfront_domain" {
  value = aws_cloudfront_distribution.portfolio_distribution.domain_name
}

# Static website endpoint
output "website_url" {
  description = "Public URL for the static website"
  value       = aws_s3_bucket_website_configuration.portfolio_website.website_endpoint
}

# API Gateway endpoint for contact form
output "contact_form_api_url" {
  description = "API Gateway URL for contact form submissions"
  value       = aws_apigatewayv2_api.contact_form_api.api_endpoint
}

# API Gateway endpoint for visitor tracking
output "visitor_api_url" {
  description = "API Gateway URL for visitor tracking"
  value       = aws_apigatewayv2_api.visitor_api.api_endpoint
}

# CloudWatch Dashboard name
output "dashboard_name" {
  description = "Name of the CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.portfolio_dashboard.dashboard_name
}

