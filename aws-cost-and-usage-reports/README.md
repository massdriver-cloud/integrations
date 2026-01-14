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
- IAM user `massdriver-costs`
- IAM policy with minimal read permissions
- Access key for the IAM user

## Permissions

The IAM user grants Massdriver read-only access:

- `s3:HeadBucket` - Verify bucket access
- `s3:ListBucket` - List report files
- `s3:GetObject` - Download reports
- `tag:GetResources` - Read resource tags for cost attribution
