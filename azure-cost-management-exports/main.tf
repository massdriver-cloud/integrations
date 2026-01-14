# Massdriver Azure Cost Management Exports Integration
#
# This OpenTofu module creates the necessary Azure resources for the Massdriver
# Cost Management Exports integration. It creates:
#   - A Resource Group for cost management resources
#   - A Storage Account for storing cost exports
#   - A Blob Container for the export files
#   - A Cost Management Export scheduled daily
#   - A Service Principal with minimal read permissions for Massdriver
#
# Usage:
#   1. Apply this configuration
#   2. Copy the outputs and provide them to Massdriver when configuring the integration
#
# Documentation: https://docs.massdriver.cloud/integrations/azure-cost-management-exports

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------

data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# LOCALS
# -----------------------------------------------------------------------------

locals {
  subscription_id = data.azurerm_subscription.current.subscription_id

  # Generate suffix using MD5 hash of subscription ID
  suffix = substr(md5(local.subscription_id), 0, 8)

  resource_group_name  = "massdriver-costs-${local.suffix}"
  storage_account_name = "mdcosts${local.suffix}"
  container_name       = "massdriver-costs-${local.suffix}"
  export_name          = "massdriver-costs"

  common_tags = {
    "managed-by" = "massdriver"
  }
}

# -----------------------------------------------------------------------------
# RESOURCE GROUP
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "costs" {
  name     = local.resource_group_name
  location = "eastus"

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# STORAGE ACCOUNT
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "costs" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.costs.name
  location                 = azurerm_resource_group.costs.location
  account_kind             = "BlobStorage"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# BLOB CONTAINER
# -----------------------------------------------------------------------------

resource "azurerm_storage_container" "exports" {
  name                  = local.container_name
  storage_account_name  = azurerm_storage_account.costs.name
  container_access_type = "private"
}

# -----------------------------------------------------------------------------
# COST MANAGEMENT EXPORT
# -----------------------------------------------------------------------------

resource "time_static" "export_start" {}

resource "azurerm_subscription_cost_management_export" "massdriver" {
  name                         = local.export_name
  subscription_id              = data.azurerm_subscription.current.id
  recurrence_type              = "Daily"
  recurrence_period_start_date = time_static.export_start.rfc3339
  recurrence_period_end_date   = timeadd(time_static.export_start.rfc3339, "17520h") # ~2 years

  export_data_storage_location {
    container_id     = azurerm_storage_container.exports.resource_manager_id
    root_folder_path = "/"
  }

  export_data_options {
    type       = "ActualCost"
    time_frame = "MonthToDate"
  }
}

# -----------------------------------------------------------------------------
# SERVICE PRINCIPAL FOR MASSDRIVER
# -----------------------------------------------------------------------------

resource "azuread_application" "massdriver" {
  display_name = "massdriver-cost-reader"

  tags = ["massdriver", "cost-management"]
}

resource "azuread_service_principal" "massdriver" {
  client_id = azuread_application.massdriver.client_id

  tags = ["massdriver", "cost-management"]
}

resource "azuread_service_principal_password" "massdriver" {
  service_principal_id = azuread_service_principal.massdriver.id
  display_name         = "massdriver-cost-reader-secret"
  end_date_relative    = "17520h" # ~2 years
}

resource "azurerm_role_assignment" "blob_reader" {
  scope                = azurerm_storage_account.costs.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_service_principal.massdriver.object_id
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.costs.name
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.costs.name
}

output "container_name" {
  description = "The name of the blob container"
  value       = azurerm_storage_container.exports.name
}

output "export_name" {
  description = "The name of the cost management export"
  value       = azurerm_subscription_cost_management_export.massdriver.name
}

output "tenant_id" {
  description = "The Azure AD tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "The Azure subscription ID"
  value       = local.subscription_id
}

output "client_id" {
  description = "The client ID of the service principal"
  value       = azuread_application.massdriver.client_id
}

output "client_secret" {
  description = "The client secret for the service principal"
  value       = azuread_service_principal_password.massdriver.value
  sensitive   = true
}

output "massdriver_integration_config" {
  description = "Configuration values to provide to Massdriver"
  value = {
    tenant_id            = data.azurerm_client_config.current.tenant_id
    subscription_id      = local.subscription_id
    client_id            = azuread_application.massdriver.client_id
    client_secret        = azuread_service_principal_password.massdriver.value
    storage_account_name = azurerm_storage_account.costs.name
    container_name       = azurerm_storage_container.exports.name
  }
  sensitive = true
}
