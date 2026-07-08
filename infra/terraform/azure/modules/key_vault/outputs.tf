output "id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "Key Vault URI."
  value       = azurerm_key_vault.this.vault_uri
}

output "secret_names" {
  description = "Names of secrets created in Key Vault."
  value       = keys(azurerm_key_vault_secret.this)
}

output "secret_ids" {
  description = "Map of Key Vault secret names to secret IDs."
  value       = { for name, secret in azurerm_key_vault_secret.this : name => secret.id }
  sensitive   = true
}

output "api_secrets_user_role_assignment_id" {
  description = "Role assignment ID for API Key Vault Secrets User."
  value       = azurerm_role_assignment.api_secrets_user.id
}
