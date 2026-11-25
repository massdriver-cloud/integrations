# Massdriver AWS IaC Coverage Integration
#
# Documentation: https://docs.massdriver.cloud/integrations/aws-iac-coverage

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.0 for the per-resource 'region' argument, which puts a Resource Explorer index in each region
      version = ">= 6.0"
    }
  }
}

variable "scope" {
  description = "What Massdriver inventories. 'account' inventories the account that runs this module. 'organization' inventories every account in the AWS Organization; run the module in the Resource Explorer delegated administrator account (or the management account)."
  type        = string

  validation {
    condition     = contains(["account", "organization"], var.scope)
    error_message = "scope must be 'account' or 'organization'."
  }
}

variable "tags" {
  description = "A map of tags to assign to the resources. These tags will be merged with common_tags, with common_tags taking precedence for the 'managed-by' key."
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Prefix used for naming resources (view, IAM user). Defaults to 'massdriver-iac-coverage'."
  type        = string
  default     = "massdriver-iac-coverage"
}

variable "create_indexes" {
  description = "Create the Resource Explorer indexes in this account. The aggregator index goes in the provider region and a local index goes in each other region in index_regions. Set to false if Resource Explorer is already turned on in this account, for example by Systems Manager Quick Setup. The aggregator index must then already be in the provider region. Defaults to true."
  type        = bool
  default     = true
}

variable "index_regions" {
  description = "Regions to index. Resources in a region without an index are not found. Defaults to all regions that are enabled in the account."
  type        = list(string)
  default     = null
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_regions" "enabled" {}

data "aws_organizations_organization" "current" {
  count = var.scope == "organization" ? 1 : 0

  return_organization_only = true
}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  aggregator_region = data.aws_region.current.region

  index_regions       = var.index_regions != null ? toset(var.index_regions) : data.aws_regions.enabled.names
  local_index_regions = var.create_indexes ? setsubtract(local.index_regions, [local.aggregator_region]) : toset([])

  # A view without a scope covers only this account.
  view_scope = var.scope == "organization" ? data.aws_organizations_organization.current[0].arn : null

  common_tags = {
    "managed-by" = "massdriver"
  }

  # Merge tags: user-provided tags first, then common_tags (common_tags wins for managed-by)
  merged_tags = merge(var.tags, local.common_tags)
}

# -----------------------------------------------------------------------------
# RESOURCE EXPLORER INDEXES
# -----------------------------------------------------------------------------

resource "aws_resourceexplorer2_index" "aggregator" {
  count = var.create_indexes ? 1 : 0

  type = "AGGREGATOR"
  tags = local.merged_tags
}

resource "aws_resourceexplorer2_index" "local" {
  for_each = local.local_index_regions

  region = each.key
  type   = "LOCAL"
  tags   = local.merged_tags
}

# -----------------------------------------------------------------------------
# RESOURCE EXPLORER VIEW
# -----------------------------------------------------------------------------

# An organization view must be in the aggregator index region.
resource "aws_resourceexplorer2_view" "massdriver" {
  name  = var.name_prefix
  scope = local.view_scope

  # Massdriver reads the tags of each resource to decide if IaC manages it.
  included_property {
    name = "tags"
  }

  tags = local.merged_tags

  depends_on = [
    aws_resourceexplorer2_index.aggregator,
    aws_resourceexplorer2_index.local,
  ]
}

# -----------------------------------------------------------------------------
# IAM USER FOR MASSDRIVER
# -----------------------------------------------------------------------------

resource "aws_iam_user" "massdriver_iac_coverage" {
  name = var.name_prefix
  tags = local.merged_tags
}

resource "aws_iam_user_policy" "massdriver_iac_coverage" {
  name = "${var.name_prefix}-policy"
  user = aws_iam_user.massdriver_iac_coverage.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          # The ListResources API is authorized by the Search action.
          Sid      = "SearchView"
          Effect   = "Allow"
          Action   = ["resource-explorer-2:Search", "resource-explorer-2:GetView"]
          Resource = aws_resourceexplorer2_view.massdriver.arn
        },
        {
          Sid      = "GetResourceTags"
          Effect   = "Allow"
          Action   = ["tag:GetResources"]
          Resource = "*"
        }
      ],
      var.scope == "organization" ? [
        {
          Sid    = "ReadOrganization"
          Effect = "Allow"
          Action = [
            "organizations:DescribeOrganization",
            "organizations:DescribeOrganizationalUnit",
            "organizations:ListAccounts",
            "organizations:ListOrganizationalUnitsForParent",
            "organizations:ListParents",
          ]
          Resource = "*"
        }
      ] : []
    )
  })
}

resource "aws_iam_access_key" "massdriver_iac_coverage" {
  user = aws_iam_user.massdriver_iac_coverage.name
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "scope" {
  description = "The inventory scope: 'account' or 'organization'"
  value       = var.scope
}

output "view_arn" {
  description = "The ARN of the Resource Explorer view"
  value       = aws_resourceexplorer2_view.massdriver.arn
}

output "view_region" {
  description = "The region of the Resource Explorer view and the aggregator index"
  value       = local.aggregator_region
}

output "account_id" {
  description = "The ID of the AWS account that holds the view"
  value       = local.account_id
}

output "access_key_id" {
  description = "The access key ID for the massdriver-iac-coverage IAM user"
  value       = aws_iam_access_key.massdriver_iac_coverage.id
}

output "secret_access_key" {
  description = "The secret access key for the massdriver-iac-coverage IAM user"
  value       = aws_iam_access_key.massdriver_iac_coverage.secret
  sensitive   = true
}

output "massdriver_integration_config" {
  description = "Configuration values to provide to Massdriver"
  value = {
    access_key_id     = aws_iam_access_key.massdriver_iac_coverage.id
    secret_access_key = aws_iam_access_key.massdriver_iac_coverage.secret
    scope             = var.scope
    view_arn          = aws_resourceexplorer2_view.massdriver.arn
    view_region       = local.aggregator_region
  }
  sensitive = true
}
