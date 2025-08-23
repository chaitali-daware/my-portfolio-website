output "bucket_name" {
  value = aws_s3_bucket.portfolio_bucket.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.portfolio_distribution.domain_name
}

output "contact_form_api_url" {
  value = "${aws_apigatewayv2_api.contact_form_api.api_endpoint}/contact"
}

output "visitor_api_url" {
  value = "${aws_apigatewayv2_api.visitor_api.api_endpoint}/visit"
}

output "acm_validation_records" {
  value = aws_acm_certificate.cert.domain_validation_options
