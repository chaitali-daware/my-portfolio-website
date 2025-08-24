provider "aws" {
  region = var.aws_region
}

# S3 Bucket
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name

  # Do NOT set ACL
}

# S3 Bucket Ownership & Public Access
resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket Policy for public read
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

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Upload website files
resource "aws_s3_object" "website_files" {
  for_each = fileset(var.local_website_path, "**/*")

  bucket = aws_s3_bucket.website.id
  key    = each.value
  source = "${var.local_website_path}/${each.value}"
}
