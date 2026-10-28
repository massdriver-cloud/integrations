# AWS Cost and Usage Reports Integration

OpenTofu module for setting up AWS Cost and Usage Reports for Massdriver.

## Documentation

Full setup guide: [docs.massdriver.cloud/integrations/aws-cost-and-usage-reports](https://docs.massdriver.cloud/integrations/aws-cost-and-usage-reports)

## Requirements

| Name | Version |
|------|---------|
| opentofu | >= 1.0 |
| aws | >= 5.16 |
| random | >= 3.0 |

## Usage

```bash
git clone https://github.com/massdriver-cloud/integrations.git
cd integrations/aws-cost-and-usage-reports

tofu init
tofu apply
```

Or as a module:

```hcl
module "massdriver_cur" {
  source = "github.com/massdriver-cloud/integrations//aws-cost-and-usage-reports?ref=v2.0.0"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| name_prefix | string | `massdriver-costs` | Prefix for the bucket, report, and IAM user names |
| bucket_region | string | `us-west-2` | Region for the S3 bucket (the report itself is always created in us-east-1) |
| cur_report_additional_artifacts | list(string) | `[]` | Extra CUR artifacts: `REDSHIFT`, `QUICKSIGHT`, `ATHENA` |
| tags | map(string) | `{}` | Tags applied to created resources |
| cost_allocation_tags | list(string) | `[]` | Massdriver tag keys to activate as cost allocation tags: `md-package`, `md-instance` (see below) |

### Cost allocation tag mode

By default Massdriver attributes costs to instances by reading resource tags from the
Resource Groups Tagging API. Each key in `cost_allocation_tags` is activated as an AWS
cost allocation tag. AWS then adds a `resourceTags/user:<key>` column to the report, and
Massdriver reads costs straight from it. This is more accurate: it covers deleted and
retagged resources and line items the Tagging API can't see, and it needs no extra API calls.

| Organization default tags | `cost_allocation_tags` |
|---------------------------|------------------------|
| Legacy | `["md-package"]` |
| Custom | `["md-instance"]` |
| Moving from legacy to custom | `["md-package", "md-instance"]` |

When the report has any cost allocation tag column, Massdriver reads tags only from those
columns. Costs for resources that carry only `md-instance` are not attributed until
`md-instance` is active.

```hcl
module "massdriver_cur" {
  source               = "github.com/massdriver-cloud/integrations//aws-cost-and-usage-reports?ref=v2.0.0"
  cost_allocation_tags = ["md-package", "md-instance"]
}
```

Notes:

- AWS rejects the activation of a key until it is in the billing data of the account. The
  key appears up to 24 hours after the first resource with that tag exists. Add
  `md-instance` after Massdriver has deployed at least one resource with that tag.
- This is a billing setting and only succeeds in the AWS **management (payer) account**.
- It applies going forward only. Costs from before the activation are not attributed by
  that key.
- If you leave the list empty, the Tagging API path is used and everything still works.

### Upgrading from v1

`v2.0.0` replaces `activate_cost_allocation_tag = true` with
`cost_allocation_tags = ["md-package"]`. The module moves the existing `md-package`
activation in state, so `tofu apply` does not deactivate it.

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | The name of the S3 bucket storing CUR reports |
| bucket_arn | The ARN of the S3 bucket |
| report_name | The name of the Cost and Usage Report |
| access_key_id | The access key ID for the massdriver-costs IAM user |
| secret_access_key | The secret access key (sensitive) |
| massdriver_integration_config | All configuration values for Massdriver (sensitive) |

## Resources Created

- S3 bucket for CUR reports
- S3 bucket policy for AWS Billing service
- Cost and Usage Report definition
- Cost allocation tag activation for each key in `cost_allocation_tags`
- IAM user `massdriver-costs`
- IAM policy with minimal read permissions
- Access key for the IAM user

## Permissions

The IAM user grants Massdriver read-only access:

- `s3:HeadBucket` - Verify bucket access
- `s3:ListBucket` - List report files
- `s3:GetObject` - Download reports
- `tag:GetResources` - Read resource tags for cost attribution
