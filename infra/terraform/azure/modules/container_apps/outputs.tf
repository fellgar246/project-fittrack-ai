output "id" {
  description = "Resource ID of the Container App."
  value       = azurerm_container_app.this.id
}

output "name" {
  description = "Name of the Container App."
  value       = azurerm_container_app.this.name
}

output "latest_revision_fqdn" {
  description = "Fully qualified domain name of the latest revision."
  value       = azurerm_container_app.this.latest_revision_fqdn
}

output "url" {
  description = "Public HTTPS URL of the Container App."
  value       = "https://${azurerm_container_app.this.latest_revision_fqdn}"
}
