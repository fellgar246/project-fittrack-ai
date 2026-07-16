output "id" {
  description = "Storage account resource ID."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint for the storage account."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "container_name" {
  description = "Private progress photo container name."
  value       = var.container_name
}

output "container_id" {
  description = "Resource ID of the private blob container."
  value       = azapi_resource.container.id
}

output "blob_delegator_role_assignment_id" {
  description = "Role assignment ID for Storage Blob Delegator when configured."
  value       = try(azurerm_role_assignment.blob_delegator[0].id, null)
}

output "blob_data_contributor_role_assignment_id" {
  description = "Role assignment ID for Storage Blob Data Contributor when configured."
  value       = try(azurerm_role_assignment.blob_data_contributor[0].id, null)
}
