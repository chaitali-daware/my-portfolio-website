output "bucket_name" {
  value       = aws_s3_bucket.portfolio_bucket.id
  description = "Name of the S3 bucket"
}

output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.portfolio_distribution.domain_name
  description = "CloudFront distribution domain"
}

output "api_gateway_url" {
  value       = aws_api_gateway_stage.api_stage.invoke_url
  description = "Invoke URL of the API Gateway"
}
