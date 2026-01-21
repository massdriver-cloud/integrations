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

## Development

### Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.0 (or Terraform >= 1.0)
- [pre-commit](https://pre-commit.com/) installed

### Setting Up Pre-commit Hooks

This repository uses pre-commit hooks to automatically format and validate OpenTofu code before commits. To set up pre-commit hooks:

1. Install pre-commit:
   ```bash
   # Using pip
   pip install pre-commit

   # Using Homebrew (macOS)
   brew install pre-commit

   # Using conda
   conda install -c conda-forge pre-commit
   ```

2. Install the git hooks:
   ```bash
   pre-commit install
   ```

3. (Optional) Run pre-commit on all files:
   ```bash
   pre-commit run --all-files
   ```

The pre-commit hooks will automatically:
- Format OpenTofu files using `tofu fmt`
- Validate OpenTofu configuration files
- Check for common issues

### Manual Formatting and Validation

You can also run formatting and validation manually:

```bash
# Format all OpenTofu files
tofu fmt -recursive

# Validate a specific module
cd aws-cost-and-usage-reports
tofu init -backend=false
tofu validate
```

## Support

For questions or issues, contact [support@massdriver.cloud](mailto:support@massdriver.cloud).
