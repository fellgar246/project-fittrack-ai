output "id" {
  description = "Resource ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "name" {
  description = "Name of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.name
}

output "principal_id" {
  description = "Principal ID of the user-assigned managed identity, used for role assignments."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "Client ID of the user-assigned managed identity, used by the Container App to reference the identity."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "acr_pull_role_assignment_id" {
  description = "Resource ID of the AcrPull role assignment."
  value       = azurerm_role_assignment.acr_pull.id
}
