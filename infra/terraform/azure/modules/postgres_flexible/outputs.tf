output "server_id" {
  description = "PostgreSQL Flexible Server resource ID."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "server_name" {
  description = "PostgreSQL Flexible Server name."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "PostgreSQL Flexible Server FQDN."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "Application database name."
  value       = azurerm_postgresql_flexible_server_database.this.name
}

output "administrator_login" {
  description = "PostgreSQL administrator login."
  value       = var.administrator_login
}

output "administrator_password" {
  description = "Generated PostgreSQL administrator password."
  value       = random_password.administrator.result
  sensitive   = true
}

output "database_url" {
  description = "Application async PostgreSQL database URL."
  value       = "postgresql+psycopg://${var.administrator_login}:${urlencode(random_password.administrator.result)}@${azurerm_postgresql_flexible_server.this.fqdn}:5432/${azurerm_postgresql_flexible_server_database.this.name}?sslmode=require"
  sensitive   = true
}
