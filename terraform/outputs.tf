output "bucket_name" {
  value       = aws_s3_bucket.site.bucket
  description = "S3 bucket hosting the frontend (private behind CloudFront)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "CloudFront URL for the site"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "api_base_url" {
  value       = aws_apigatewayv2_api.api.api_endpoint
  description = "Base URL for HTTP API"
}

output "contact_api_url" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/contact"
}

output "visitor_api_url" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/visitor"
}
