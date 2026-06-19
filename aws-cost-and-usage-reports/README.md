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
  source = "github.com/massdriver-cloud/integrations//aws-cost-and-usage-reports"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| name_prefix | string | `massdriver-costs` | Prefix for the bucket, report, and IAM user names |
| bucket_region | string | `us-west-2` | Region for the S3 bucket (the report itself is always created in us-east-1) |
| cur_report_additional_artifacts | list(string) | `[]` | Extra CUR artifacts: `REDSHIFT`, `QUICKSIGHT`, `ATHENA` |
| tags | map(string) | `{}` | Tags applied to created resources |
| activate_cost_allocation_tag | bool | `false` | Activate the `md-package` cost allocation tag (see below) |

### Cost allocation tag mode

By default Massdriver attributes costs to packages by reading resource tags from the
Resource Groups Tagging API. If you set `activate_cost_allocation_tag = true`, the module
activates `md-package` as an AWS cost allocation tag. AWS then adds a
`resourceTags/user:md-package` column to the report, and Massdriver reads costs straight
from it — more accurate (it covers deleted/retagged resources and line items the Tagging
API can't see) and with no extra API calls.

Notes:

- This is a billing setting and only succeeds in the AWS **management (payer) account**.
- It applies going forward only and can take ~24 hours to appear in reports.
- If you leave it `false`, the Tagging API path is used and everything still works.

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
- Cost allocation tag activation for `md-package` (only when `activate_cost_allocation_tag = true`)
- IAM user `massdriver-costs`
- IAM policy with minimal read permissions
- Access key for the IAM user

## Permissions

The IAM user grants Massdriver read-only access:

- `s3:HeadBucket` - Verify bucket access
- `s3:ListBucket` - List report files
- `s3:GetObject` - Download reports
- `tag:GetResources` - Read resource tags for cost attribution
