provider "aws" {
  region = var.aws_region
}

# S3 Bucket
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

# Bucket Policy to allow public read
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# Upload website files
resource "aws_s3_bucket_object" "website_files" {
  for_each = fileset(var.local_website_path, "**/*")

  bucket = aws_s3_bucket.website.id
  key    = each.value
  source = "${var.local_website_path}/${each.value}"
  acl    = "public-read"
}
