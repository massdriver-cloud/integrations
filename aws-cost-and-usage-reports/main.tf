# Massdriver AWS Cost and Usage Reports Integration
#
# This OpenTofu module creates the necessary AWS resources for the Massdriver
# Cost and Usage Reports integration.
#
# Documentation: https://docs.massdriver.cloud/integrations/aws-cost-and-usage-reports

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  bucket_suffix = substr(md5(local.account_id), 0, 8)
  bucket_name   = "massdriver-costs-${local.bucket_suffix}"
  report_name   = "massdriver-costs"

  common_tags = {
    "managed-by" = "massdriver"
  }
}

# -----------------------------------------------------------------------------
# S3 BUCKET
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "cur_reports" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_policy" "cur_reports" {
  bucket = aws_s3_bucket.cur_reports.id

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid       = "AllowAWSBillingAccessGetPolicy"
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
        Resource  = aws_s3_bucket.cur_reports.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "aws:SourceArn"     = "arn:aws:cur:us-east-1:${local.account_id}:definition/*"
          }
        }
      },
      {
        Sid       = "AllowAWSBillingAccessPut"
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = ["s3:PutObject"]
        Resource  = "${aws_s3_bucket.cur_reports.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "aws:SourceArn"     = "arn:aws:cur:us-east-1:${local.account_id}:definition/*"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# COST AND USAGE REPORT (us-east-1 only)
# -----------------------------------------------------------------------------

resource "aws_cur_report_definition" "massdriver" {
  report_name                = local.report_name
  time_unit                  = "DAILY"
  format                     = "textORcsv"
  compression                = "ZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = aws_s3_bucket.cur_reports.bucket
  s3_prefix                  = "reports"
  s3_region                  = "us-east-1"
  additional_artifacts       = ["REDSHIFT", "QUICKSIGHT"]
  report_versioning          = "OVERWRITE_REPORT"

  depends_on = [aws_s3_bucket_policy.cur_reports]
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR MASSDRIVER
# -----------------------------------------------------------------------------

resource "random_uuid" "external_id" {}

resource "aws_iam_role" "massdriver_cur_reader" {
  name = "massdriver-cur-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.massdriver_aws_account_id }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "sts:ExternalId" = random_uuid.external_id.result } }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cur_reader" {
  name = "massdriver-cur-reader-policy"
  role = aws_iam_role.massdriver_cur_reader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.cur_reports.arn
      },
      {
        Sid      = "GetObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.cur_reports.arn}/*"
      },
      {
        Sid      = "GetResourceTags"
        Effect   = "Allow"
        Action   = ["tag:GetResources"]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------

variable "massdriver_aws_account_id" {
  description = "The AWS account ID that Massdriver uses to assume the role"
  type        = string
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "bucket_name" {
  description = "The name of the S3 bucket storing CUR reports"
  value       = aws_s3_bucket.cur_reports.bucket
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.cur_reports.arn
}

output "report_name" {
  description = "The name of the Cost and Usage Report"
  value       = aws_cur_report_definition.massdriver.report_name
}

output "iam_role_arn" {
  description = "The ARN of the IAM role for Massdriver"
  value       = aws_iam_role.massdriver_cur_reader.arn
}

output "external_id" {
  description = "The external ID required when assuming the role"
  value       = random_uuid.external_id.result
  sensitive   = true
}

output "massdriver_integration_config" {
  description = "Configuration values to provide to Massdriver"
  value = {
    iam_role_arn = aws_iam_role.massdriver_cur_reader.arn
    external_id  = random_uuid.external_id.result
    bucket_name  = aws_s3_bucket.cur_reports.bucket
  }
  sensitive = true
}
