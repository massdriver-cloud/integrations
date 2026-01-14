# AWS Cost and Usage Reports Integration

OpenTofu module for setting up AWS Cost and Usage Reports for Massdriver.

## Documentation

Full setup guide: [docs.massdriver.cloud/integrations/aws-cost-and-usage-reports](https://docs.massdriver.cloud/integrations/aws-cost-and-usage-reports)

## Requirements

| Name | Version |
|------|---------|
| opentofu | >= 1.0 |
| aws | >= 5.0 |
| random | >= 3.0 |

## Usage

```hcl
module "massdriver_cur" {
  source = "github.com/massdriver-cloud/integrations//aws-cost-and-usage-reports"

  massdriver_aws_account_id = "YOUR_MASSDRIVER_ACCOUNT_ID"
}
```

Or clone and apply directly:

```bash
git clone https://github.com/massdriver-cloud/integrations.git
cd integrations/aws-cost-and-usage-reports

tofu init
tofu apply
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| massdriver_aws_account_id | The AWS account ID that Massdriver uses to assume the role | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | The name of the S3 bucket storing CUR reports |
| bucket_arn | The ARN of the S3 bucket |
| report_name | The name of the Cost and Usage Report |
| iam_role_arn | The ARN of the IAM role for Massdriver |
| external_id | The external ID required when assuming the role (sensitive) |
| massdriver_integration_config | All configuration values for Massdriver (sensitive) |

## Resources Created

- S3 bucket for CUR reports
- S3 bucket policy for AWS Billing service
- Cost and Usage Report definition
- IAM role for cross-account access
- IAM policy with minimal read permissions

## Permissions

The IAM role grants Massdriver read-only access:

- `s3:ListBucket` - List report files
- `s3:GetObject` - Download reports
- `tag:GetResources` - Read resource tags for cost attribution
