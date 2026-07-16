resource "azurerm_storage_account" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = var.public_network_access_enabled
  https_traffic_only_enabled      = true

  blob_properties {
    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }
    container_delete_retention_policy {
      days = var.container_soft_delete_retention_days
    }
  }

  tags = var.tags
}

resource "azapi_resource" "container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  name      = var.container_name
  parent_id = "${azurerm_storage_account.this.id}/blobServices/default"

  body = {
    properties = {
      publicAccess = "None"
    }
  }
}

resource "azurerm_role_assignment" "blob_delegator" {
  count = var.api_identity_principal_id != "" ? 1 : 0

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Delegator"
  principal_id         = var.api_identity_principal_id
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  count = var.api_identity_principal_id != "" ? 1 : 0

  scope                = azapi_resource.container.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.api_identity_principal_id
}

resource "time_sleep" "wait_for_storage_rbac_propagation" {
  count = var.api_identity_principal_id != "" ? 1 : 0

  depends_on      = [azurerm_role_assignment.blob_delegator, azurerm_role_assignment.blob_data_contributor]
  create_duration = "60s"
}
