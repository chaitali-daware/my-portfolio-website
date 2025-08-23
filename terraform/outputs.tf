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
  description = "Public S3 website endpoint (non-https)"
  value       = aws_s3_bucket_website_configuration.portfolio_website.website_endpoint
}

output "contact_form_api_url" {
  description = "Full contact form endpoint (POST)"
  value       = "${aws_apigatewayv2_api.contact_form_api.api_endpoint}/contact"
}

output "visitor_api_url" {
  description = "Full visitor endpoint (POST)"
  value       = "${aws_apigatewayv2_api.visitor_api.api_endpoint}/visit"
}

output "acm_cert_arn" {
  description = "ACM cert ARN (in us-east-1)"
  value       = aws_acm_certificate.cert.arn
}

output "acm_domain_validation_records" {
  description = "ACM DNS validation records (copy to Namecheap)"
  value = [
    for dvo in aws_acm_certificate.cert.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}
