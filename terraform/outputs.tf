output "bucket_name" {
  value = aws_s3_bucket.portfolio_bucket.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.portfolio_distribution.domain_name
}

output "acm_domain_validation" {
  description = "Add this DNS record in Namecheap for SSL validation"
  value       = aws_acm_certificate.cert.domain_validation_options
}
