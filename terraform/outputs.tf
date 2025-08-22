output "bucket_name" {
  value = aws_s3_bucket.portfolio_bucket.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.portfolio_distribution.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.portfolio_distribution.id
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.portfolio_website.website_endpoint
}

output "contact_form_api_url" {
  value = aws_apigatewayv2_stage.contact_form_stage.invoke_url
}

output "visitor_api_url" {
  value = aws_apigatewayv2_stage.visitor_stage.invoke_url
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.portfolio_dashboard.dashboard_name
}

output "acm_cert_arn" {
  value = aws_acm_certificate.cert.arn
}

output "acm_domain_validation_options" {
  value = jsonencode(aws_acm_certificate.cert.domain_validation_options)
}
