output "s3_bucket_name" {
  value = aws_s3_bucket.website.id
}

output "s3_website_endpoint" {
  value = aws_s3_bucket.website.website_endpoint
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.cert.arn
}
