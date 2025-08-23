# outputs.tf

output "acm_cert_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.cert.arn
}

output "acm_validation_records" {
  description = "CNAME records to validate ACM certificate"
  value       = [
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

output "contact_api_url" {
  description = "API Gateway endpoint for Contact Form Lambda"
  value       = aws_apigatewayv2_api.contact_api.api_endpoint
}

output "visitor_api_url" {
  description = "API Gateway endpoint for Visitor Logger Lambda"
  value       = aws_apigatewayv2_api.visitor_api.api_endpoint
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain" {
  description = "CloudFront Distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "s3_website_url" {
  description = "S3 static website endpoint"
  value       = aws_s3_bucket_website_configuration.website_config.website_endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket name for static website"
  value       = aws_s3_bucket.website.bucket
}
