output "bucket_name" {
  description = "The name of the S3 bucket hosting the portfolio website"
  value       = aws_s3_bucket.portfolio_bucket.bucket
}

output "cloudfront_domain" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.portfolio_distribution.domain_name
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.cert.arn
}

output "api_gateway_url" {
  description = "The invoke URL for the API Gateway"
  value       = aws_api_gateway_rest_api.api.execution_arn
}
