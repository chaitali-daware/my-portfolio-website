output "api_gateway_url" {
  description = "Invoke URL for API Gateway"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "website_bucket" {
  description = "S3 Bucket name for website"
  value       = aws_s3_bucket.site.id
}

output "acm_validation_cname" {
  description = "ACM validation details for DNS"
  value       = aws_acm_certificate.cert.domain_validation_options
}

output "custom_domain" {
  description = "Your custom domain name"
  value       = var.domain_name
}
