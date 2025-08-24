output "s3_bucket_name" {
  value = aws_s3_bucket.website.id
}

output "s3_website_endpoint" {
  value = aws_s3_bucket.website.bucket_regional_domain_name
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}
