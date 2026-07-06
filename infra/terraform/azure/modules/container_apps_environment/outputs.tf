output "id" {
  description = "ID of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.id
}

output "name" {
  description = "Name of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.name
}

output "default_domain" {
  description = "Default domain of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.default_domain
}
