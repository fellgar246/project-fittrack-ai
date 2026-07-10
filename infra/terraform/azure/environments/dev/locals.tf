locals {
  # Azure resource names (ACR, Storage Account) forbid hyphens/uppercase and
  # have tight length limits, so we derive a normalized project name for them.
  normalized_project_name = replace(lower(var.project_name), "-", "")
  name_prefix             = "${var.project_name}-${var.environment}"

  common_tags = {
    project     = var.project_name
    environment = var.environment
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
  }

  # Planned names for future blocks (4.4+). Nothing below is created yet
  # except the optional resource group in main.tf.
  resource_group_name     = "rg-${var.project_name}-${var.environment}"
  acr_name                = substr("acr${local.normalized_project_name}${var.environment}${var.unique_suffix}", 0, 50)
  storage_account_name    = "st${local.normalized_project_name}${var.environment}"
  container_app_env_name  = "cae-${var.project_name}-${var.environment}"
  container_app_api_name  = "ca-${var.project_name}-api-${var.environment}"
  api_identity_name       = "id-${var.project_name}-api-${var.environment}"
  postgres_server_name    = var.unique_suffix != "" ? "psql-${var.project_name}-pg-${var.unique_suffix}" : "psql-${var.project_name}-${var.environment}"
  postgres_database_name  = "fittrack_ai"
  log_analytics_workspace = "log-${var.project_name}-${var.environment}"
  key_vault_name          = lower(substr("kv${replace(local.name_prefix, "-", "")}${var.unique_suffix}", 0, 24))

  api_key_vault_secrets = merge(
    {
      "JWT-SECRET-KEY" = var.api_jwt_secret_key
      "DATABASE-URL"   = var.create_postgres ? module.postgres_flexible[0].database_url : var.api_database_url
    },
    var.api_azure_openai_endpoint != "" ? {
      "AZURE-OPENAI-ENDPOINT" = var.api_azure_openai_endpoint
    } : {},
    var.api_azure_openai_api_key != "" ? {
      "AZURE-OPENAI-API-KEY" = var.api_azure_openai_api_key
    } : {},
    var.api_azure_openai_deployment != "" ? {
      "AZURE-OPENAI-DEPLOYMENT" = var.api_azure_openai_deployment
    } : {},
  )
}
