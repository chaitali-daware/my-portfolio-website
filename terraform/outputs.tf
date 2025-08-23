output "s3_bucket"                 { value = aws_s3_bucket.site.id }
output "cloudfront_distribution_id"{ value = aws_cloudfront_distribution.cdn.id }
output "cloudfront_domain_name"    { value = aws_cloudfront_distribution.cdn.domain_name }
output "visitor_api_url"           { value = local.visitor_api_url }
output "contact_api_url"           { value = local.contact_api_url }

# Show ACM DNS CNAMEs to add in Namecheap
output "acm_validation_records" {
  description = "Add these CNAMEs in Namecheap DNS"
  value = [
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    {
      name  = dvo.resource_record_name,
      type  = dvo.resource_record_type,
      value = dvo.resource_record_value
    }
  ]
}
