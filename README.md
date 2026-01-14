# Massdriver Integrations

OpenTofu modules for setting up cloud resources required by Massdriver integrations.

## Overview

These modules create the necessary cloud infrastructure for Massdriver to integrate with your cloud accounts. Each module follows the principle of least privilege, granting only the minimal permissions required.

## Available Integrations

| Integration | Cloud | Documentation |
|-------------|-------|---------------|
| [AWS Cost and Usage Reports](./aws-cost-and-usage-reports) | AWS | [docs.massdriver.cloud/integrations/aws-cost-and-usage-reports](https://docs.massdriver.cloud/integrations/aws-cost-and-usage-reports) |
| [Azure Cost Management Exports](./azure-cost-management-exports) | Azure | [docs.massdriver.cloud/integrations/azure-cost-management-exports](https://docs.massdriver.cloud/integrations/azure-cost-management-exports) |

## Usage

1. Clone this repository
2. Navigate to the integration directory
3. Follow the README for that integration

```bash
git clone https://github.com/massdriver-cloud/integrations.git
cd integrations/<integration-name>
tofu init
tofu apply
```

## Requirements

- [OpenTofu](https://opentofu.org/) >= 1.0 (or Terraform >= 1.0)
- Cloud provider CLI authenticated (AWS CLI, Azure CLI)
- Appropriate permissions to create the required resources

## Support

For questions or issues, contact [support@massdriver.cloud](mailto:support@massdriver.cloud).
