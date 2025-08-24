output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "s3_website_endpoint" {
  description = "The S3 website endpoint URL"
  value       = aws_s3_bucket.website.website_endpoint
}
