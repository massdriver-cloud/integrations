# AWS IaC Coverage Integration

OpenTofu module for setting up AWS Resource Explorer for the Massdriver IaC Coverage integration.

## Documentation

Full setup guide: [docs.massdriver.cloud/integrations/aws-iac-coverage](https://docs.massdriver.cloud/integrations/aws-iac-coverage)

## Requirements

| Name | Version |
|------|---------|
| opentofu | >= 1.0 |
| aws | >= 6.0 |

## Usage

Set `scope` to `account` or `organization`.

```bash
git clone https://github.com/massdriver-cloud/integrations.git
cd integrations/aws-iac-coverage

tofu init
tofu apply -var scope=account
```

Or as a module:

```hcl
module "massdriver_iac_coverage" {
  source = "github.com/massdriver-cloud/integrations//aws-iac-coverage"
  scope  = "account"
}
```

The provider region is the aggregator index region. The view is created in that region.

### Account scope

Run the module in the account to inventory.

### Organization scope

Run the module in the Resource Explorer delegated administrator account. You can also
run it in the management account. Complete these steps first, in the management account:

1. Enable trusted access for Resource Explorer in AWS Organizations.
2. Register the delegated administrator account for Resource Explorer.
3. Turn on Resource Explorer in the member accounts, with the aggregator index in the
   same region as this module. Systems Manager Quick Setup for Resource Explorer does
   this for the whole organization or for selected OUs.

The module creates indexes only in the account that runs it. The organization view
shows resources only from member accounts that have an index.

If Quick Setup already created indexes in the account that runs the module, set
`create_indexes = false`.

AWS reference: [Turning on multi-account search](https://docs.aws.amazon.com/resource-explorer/latest/userguide/manage-service-multi-account.html)

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| scope | string | (required) | `account` or `organization` |
| name_prefix | string | `massdriver-iac-coverage` | Prefix for the view and IAM user names |
| create_indexes | bool | `true` | Create the aggregator index in the provider region and a local index in each other region in `index_regions` |
| index_regions | list(string) | all enabled regions | Regions to index |
| tags | map(string) | `{}` | Tags applied to created resources |

## Outputs

| Name | Description |
|------|-------------|
| scope | The inventory scope |
| view_arn | The ARN of the Resource Explorer view |
| view_region | The region of the view and the aggregator index |
| account_id | The ID of the AWS account that holds the view |
| access_key_id | The access key ID for the massdriver-iac-coverage IAM user |
| secret_access_key | The secret access key (sensitive) |
| massdriver_integration_config | All configuration values for Massdriver (sensitive) |

## Resources Created

- Resource Explorer aggregator index in the provider region
- Resource Explorer local index in each other region in `index_regions`
- Resource Explorer view with the `tags` property, scoped to the account or to the organization
- IAM user `massdriver-iac-coverage`
- IAM policy with minimal read permissions
- Access key for the IAM user

All resources have the tag `managed-by=massdriver`. Massdriver does not show them in IaC coverage.

## Permissions

The IAM user grants Massdriver read-only access:

- `resource-explorer-2:Search` - Search the view. This action also authorizes the `ListResources` API.
- `resource-explorer-2:GetView` - Verify the view
- `tag:GetResources` - Read resource tags

In `organization` scope only:

- `organizations:DescribeOrganization` - Read the organization
- `organizations:ListAccounts` - List the accounts
- `organizations:ListParents` - Find the OU of each account
- `organizations:DescribeOrganizationalUnit` - Read OU names
- `organizations:ListOrganizationalUnitsForParent` - List the OU tree

The Resource Explorer actions apply only to the view that the module creates.
