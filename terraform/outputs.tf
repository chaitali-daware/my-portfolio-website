output "s3_website_url" {
  value = aws_s3_bucket.website.website_endpoint
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "contact_api_url" {
  value = aws_apigatewayv2_api.contact_api.api_endpoint
}

output "visitor_api_url" {
  value = aws_apigatewayv2_api.visitor_api.api_endpoint
}

output "acm_validation_records" {
  value = [for r in aws_route53_record.acm_validation : {
    name  = r.name
    type  = r.type
    value = r.records[0]
  }]
}
