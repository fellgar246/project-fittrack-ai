output "resource_names" {
  description = "Planned Azure resource names for the dev environment."
  value = {
    resource_group_name     = local.resource_group_name
    acr_name                = local.acr_name
    storage_account_name    = local.storage_account_name
    container_app_env_name  = local.container_app_env_name
    container_app_api_name  = local.container_app_api_name
    postgres_server_name    = local.postgres_server_name
    postgres_database_name  = local.postgres_database_name
    log_analytics_workspace = local.log_analytics_workspace
  }
}

output "common_tags" {
  description = "Common tags applied to future resources."
  value       = local.common_tags
}

output "resource_group_enabled" {
  description = "Whether the Resource Group module is enabled."
  value       = var.create_resource_group
}

output "resource_group_name" {
  description = "Resource Group name when created, otherwise the planned name."
  value       = coalesce(one(module.resource_group[*].name), local.resource_group_name)
}

output "resource_group_id" {
  description = "Resource Group ID when created. Null when disabled."
  value       = one(module.resource_group[*].id)
}

output "resource_group_location" {
  description = "Resource Group location when created, otherwise the configured location."
  value       = coalesce(one(module.resource_group[*].location), var.location)
}

output "acr_enabled" {
  description = "Whether the Azure Container Registry module is enabled."
  value       = var.create_acr
}

output "acr_name" {
  description = "Azure Container Registry name when created, otherwise the planned name."
  value       = coalesce(one(module.acr[*].name), local.acr_name)
}

output "acr_id" {
  description = "Azure Container Registry ID when created. Null when disabled."
  value       = one(module.acr[*].id)
}

output "acr_login_server" {
  description = "Azure Container Registry login server when created. Null when disabled."
  value       = one(module.acr[*].login_server)
}

output "planned_modules" {
  description = "Planned Terraform modules for future Azure services, in dependency order."
  value = [
    "resource_group",
    "acr",
    "managed_identities",
    "key_vault",
    "networking",
    "postgres_flexible",
    "monitoring",
    "container_apps_environment",
    "container_apps",
  ]
}
