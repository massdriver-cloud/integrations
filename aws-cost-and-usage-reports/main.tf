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
      source = "hashicorp/aws"
      # >= 5.16 for the aws_ce_cost_allocation_tag resource
      version = ">= 5.16"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

variable "tags" {
  description = "A map of tags to assign to the resources. These tags will be merged with common_tags, with common_tags taking precedence for the 'managed-by' key."
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Prefix used for naming resources (bucket, report, IAM user). Defaults to 'massdriver-costs'."
  type        = string
  default     = "massdriver-costs"
}

variable "cur_report_additional_artifacts" {
  description = "List of additional artifacts to include in the Cost and Usage Report. Valid options: 'REDSHIFT', 'QUICKSIGHT', 'ATHENA'. Defaults to an empty list."
  type        = list(string)
  default     = []
}

variable "bucket_region" {
  description = "The AWS region where the S3 bucket will be created. This must match the region where the bucket is actually located. Defaults to 'us-west-2'."
  type        = string
  default     = "us-west-2"
}

variable "cost_allocation_tags" {
  description = "Massdriver tag keys to activate as AWS cost allocation tags: 'md-package', 'md-instance', or both. For each active key, the Cost and Usage Report includes a 'resourceTags/user:<key>' column and Massdriver reads costs directly from it instead of calling the Resource Groups Tagging API. Organizations on the legacy default tags use 'md-package'. Organizations with custom default tags use 'md-instance'. AWS rejects the activation of a key until it is in the billing data of the account, up to 24 hours after the first resource with that tag exists. This is a billing setting that must be applied in the AWS management (payer) account. It applies going forward only. Leave empty to use the Tagging API."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for tag in var.cost_allocation_tags : contains(["md-package", "md-instance"], tag)])
    error_message = "Each entry in cost_allocation_tags must be 'md-package' or 'md-instance'."
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  bucket_suffix = substr(md5(local.account_id), 0, 8)
  bucket_name   = "${var.name_prefix}-${local.bucket_suffix}"
  report_name   = var.name_prefix

  common_tags = {
    "managed-by" = "massdriver"
  }

  # Merge tags: user-provided tags first, then common_tags (common_tags wins for managed-by)
  merged_tags = merge(var.tags, local.common_tags)
}

# -----------------------------------------------------------------------------
# S3 BUCKET
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "cur_reports" {
  bucket = local.bucket_name
  tags   = local.merged_tags
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
  s3_region                  = var.bucket_region
  # additional_artifacts options: "REDSHIFT", "QUICKSIGHT", "ATHENA"
  additional_artifacts = var.cur_report_additional_artifacts

  report_versioning = "OVERWRITE_REPORT"

  depends_on = [aws_s3_bucket_policy.cur_reports]
}

# -----------------------------------------------------------------------------
# COST ALLOCATION TAG (optional, management/payer account only)
# -----------------------------------------------------------------------------
# Activating a Massdriver tag as a cost allocation tag adds a
# 'resourceTags/user:<key>' column to the CUR. Massdriver auto-detects that
# column and reads costs directly from it (more accurate, no Tagging API calls).
# This is a billing-level setting and only succeeds in the management/payer account.

resource "aws_ce_cost_allocation_tag" "massdriver" {
  for_each = toset(var.cost_allocation_tags)

  tag_key = each.key
  status  = "Active"
}

moved {
  from = aws_ce_cost_allocation_tag.md_package[0]
  to   = aws_ce_cost_allocation_tag.massdriver["md-package"]
}

# -----------------------------------------------------------------------------
# IAM USER FOR MASSDRIVER
# -----------------------------------------------------------------------------

resource "aws_iam_user" "massdriver_costs" {
  name = var.name_prefix
  tags = local.merged_tags
}

resource "aws_iam_user_policy" "massdriver_costs" {
  name = "${var.name_prefix}-policy"
  user = aws_iam_user.massdriver_costs.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "HeadBucket"
        Effect   = "Allow"
        Action   = ["s3:HeadBucket"]
        Resource = aws_s3_bucket.cur_reports.arn
      },
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

resource "aws_iam_access_key" "massdriver_costs" {
  user = aws_iam_user.massdriver_costs.name
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

output "access_key_id" {
  description = "The access key ID for the massdriver-costs IAM user"
  value       = aws_iam_access_key.massdriver_costs.id
}

output "secret_access_key" {
  description = "The secret access key for the massdriver-costs IAM user"
  value       = aws_iam_access_key.massdriver_costs.secret
  sensitive   = true
}

output "massdriver_integration_config" {
  description = "Configuration values to provide to Massdriver"
  value = {
    access_key_id     = aws_iam_access_key.massdriver_costs.id
    secret_access_key = aws_iam_access_key.massdriver_costs.secret
    bucket_name       = aws_s3_bucket.cur_reports.bucket
    bucket_region     = aws_s3_bucket.cur_reports.region
  }
  sensitive = true
}
