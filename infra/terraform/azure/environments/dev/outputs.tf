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

output "resource_group_id" {
  description = "ID of the resource group, if create_resource_group is true. Null otherwise."
  value       = one(module.resource_group[*].id)
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
