output "s3_bucket_name" {
  value = aws_s3_bucket.website.id
}

output "s3_website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_config.website_endpoint
}
