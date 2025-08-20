# Output the name of the S3 bucket hosting the portfolio
output "bucket_name" {
  value = aws_s3_bucket.portfolio_bucket.bucket
  # This returns the actual bucket name created in AWS
}


# Output the CloudFront distribution domain name
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.portfolio_distribution.domain_name
  # Useful to access the website via HTTPS through CloudFront
}


# Output the CloudFront distribution ID
output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.portfolio_distribution.id
  # Can be used for invalidation or programmatic updates
}


# Output the public S3 website endpoint (non-HTTPS)
output "website_url" {
  description = "Public S3 website endpoint (non-https)"
  value       = aws_s3_bucket_website_configuration.portfolio_website.website_endpoint
  # This is the raw S3 website URL (http://bucket-name.s3-website-region.amazonaws.com)
}


# Output the full API endpoint for the contact form
output "contact_form_api_url" {
  description = "Full contact form endpoint (POST)"
  value       = "${aws_apigatewayv2_api.contact_form_api.api_endpoint}/contact"
  # Frontend can use this URL to submit contact form data
}


# Output the full API endpoint for visitor logging
output "visitor_api_url" {
  description = "Full visitor endpoint (POST)"
  value       = "${aws_apigatewayv2_api.visitor_api.api_endpoint}/visit"
  # Frontend can call this URL to log page visits
}


# Output the name of the CloudWatch dashboard
output "dashboard_name" {
  description = "Name of CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.portfolio_dashboard.dashboard_name
  # Dashboard shows metrics for visitor logs, contact submissions, etc.
}


# Output the ACM certificate ARN
output "acm_cert_arn" {
  description = "ACM cert ARN (in us-east-1)"
  value       = aws_acm_certificate.cert.arn
  # Required for attaching SSL to CloudFront distribution
}


# Output the ACM DNS validation options
output "acm_domain_validation_options" {
  description = "ACM DNS validation record info (copy to Namecheap)"
  value       = jsonencode(aws_acm_certificate.cert.domain_validation_options)
  # Provides the CNAME records you need to add to your Namecheap domain for validation
}

