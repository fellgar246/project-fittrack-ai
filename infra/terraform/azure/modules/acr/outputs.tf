output "id" {
  description = "ID of the Azure Container Registry."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server of the Azure Container Registry."
  value       = azurerm_container_registry.this.login_server
}
