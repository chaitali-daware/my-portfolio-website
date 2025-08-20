# Cloud-Integrated Portfolio (Automated infra, Namecheap DNS)

This repository provisions:
- S3 + CloudFront (CDN)
- ACM certificate (requested in us-east-1, DNS validation required)
- API Gateway (HTTP) + 2 Lambda functions
- DynamoDB tables
- CloudWatch Dashboard & alarms
- CI/CD via GitHub Actions (packaging lambdas, terraform apply, upload frontend, invalidate CloudFront)

Important: You use **Namecheap** for DNS. Terraform will request an ACM certificate and output DNS validation CNAME record(s). You must add those CNAME(s) to Namecheap DNS before CloudFront can be configured with the certificate.

## Quick steps to deploy

1. Add AWS credentials to GitHub Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. Push to `main`. The GitHub Action will:
   - zip lambda code
   - run `terraform apply`
   - output ACM validation info (as JSON). Copy it.

3. In Namecheap:
   - Go to Domain List → Manage → Advanced DNS.
   - Add the CNAME records shown by Terraform `acm_domain_validation_options`.
   - Wait for DNS to propagate (usually minutes; sometimes up to 1 hour).

4. Re-run the GitHub Action (push an empty commit or re-run) — Terraform will validate the certificate, CloudFront will be associated with the certificate, and end-to-end HTTPS will work.

5. After full success you should see `contact_form_api_url` and `visitor_api_url` outputs. GitHub Actions replaces placeholders in `frontend/script.js` automatically and uploads frontend to S3.

## Manual DNS records you must add:
- ACM DNS validation CNAME (from terraform output `acm_domain_validation_options`)
- An A (ALIAS) or CNAME record in Namecheap to point your domain to CloudFront. CloudFront provides a domain like `dxxxxxxxx.cloudfront.net`. In Namecheap you add:
  - Host: `@` (or your subdomain like `www`)
  - Type: CNAME (if Namecheap supports ALIAS for root you can use that; otherwise use `www` CNAME and use URL redirect for root)
  - Value: `<cloudfront_domain>` (from terraform output `cloudfront_domain`)

## Notes
- Because Namecheap does not have Terraform automation here, DNS steps are manual.
- If you prefer full automation for DNS, move DNS to Route53 and we can automate the CNAME creation and ACM validation.
