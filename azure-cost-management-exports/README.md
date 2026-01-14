# Azure Cost Management Exports Integration

OpenTofu module for setting up Azure Cost Management Exports for Massdriver.

## Documentation

Full setup guide: [docs.massdriver.cloud/integrations/azure-cost-management-exports](https://docs.massdriver.cloud/integrations/azure-cost-management-exports)

## Requirements

| Name | Version |
|------|---------|
| opentofu | >= 1.0 |
| azurerm | >= 3.0 |
| azuread | >= 2.0 |
| random | >= 3.0 |
| time | >= 0.9 |

## Usage

```hcl
module "massdriver_costs" {
  source = "github.com/massdriver-cloud/integrations//azure-cost-management-exports"
}
```

Or clone and apply directly:

```bash
git clone https://github.com/massdriver-cloud/integrations.git
cd integrations/azure-cost-management-exports

az login
tofu init
tofu apply
```

## Outputs

| Name | Description |
|------|-------------|
| resource_group_name | The name of the resource group |
| storage_account_name | The name of the storage account |
| container_name | The name of the blob container |
| export_name | The name of the cost management export |
| tenant_id | The Azure AD tenant ID |
| subscription_id | The Azure subscription ID |
| client_id | The client ID of the service principal |
| client_secret | The client secret (sensitive) |
| massdriver_integration_config | All configuration values for Massdriver (sensitive) |

## Resources Created

- Resource Group for cost management resources
- Storage Account (Blob Storage, Standard LRS)
- Blob Container for export files
- Cost Management Export (daily, ActualCost)
- Azure AD Application
- Service Principal with password
- Role Assignment (Storage Blob Data Reader)

## Permissions

The service principal is granted minimal read-only access:

- **Role**: Storage Blob Data Reader
- **Scope**: Storage account only
