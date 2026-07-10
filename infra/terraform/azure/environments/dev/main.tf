# Block 4.4 — modular architecture alignment.
#
# The resource group now comes from modules/resource_group instead of being
# declared directly here. It stays gated behind create_resource_group (default
# false), so this block still creates zero real Azure resources by default.
# Enabling it (create_resource_group = true) and running the first real
# `terraform apply` is deferred to Block 4.5. Every other Azure service
# (ACR, Key Vault, Postgres, Container Apps, ...) will be its own module under
# modules/, wired here behind its own create_* flag once implemented — see
# modules/README.md for the full planned module flow.

data "azurerm_client_config" "current" {}

module "resource_group" {
  source = "../../modules/resource_group"
  count  = var.create_resource_group ? 1 : 0

  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Block 4.7 — first real module beyond the resource group. Gated behind
# create_acr (default false); create_acr's validation in variables.tf
# guarantees create_resource_group is also true whenever this is enabled, so
# module.resource_group[0] is always safe to reference here.
module "acr" {
  source = "../../modules/acr"
  count  = var.create_acr ? 1 : 0

  name                = local.acr_name
  resource_group_name = module.resource_group[0].name
  location            = module.resource_group[0].location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled
  tags                = local.common_tags
}

# Block 4.10 — observability for the future Container Apps Environment. Gated behind
# create_monitoring (default false); its validation in variables.tf guarantees
# create_resource_group is also true whenever this is enabled.
module "monitoring" {
  source = "../../modules/monitoring"
  count  = var.create_monitoring ? 1 : 0

  workspace_name      = local.log_analytics_workspace
  resource_group_name = module.resource_group[0].name
  location            = module.resource_group[0].location
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = local.common_tags
}

# Block 4.10 — shared Container Apps runtime. Gated behind
# create_container_apps_environment (default false); its validations in variables.tf
# guarantee create_resource_group and create_monitoring are also true whenever this is
# enabled, so module.resource_group[0] and module.monitoring[0] are always safe here.
module "container_apps_environment" {
  source = "../../modules/container_apps_environment"
  count  = var.create_container_apps_environment ? 1 : 0

  name                       = local.container_app_env_name
  resource_group_name        = module.resource_group[0].name
  location                   = module.resource_group[0].location
  log_analytics_workspace_id = module.monitoring[0].id
  tags                       = local.common_tags
}

# Block 4.12 — passwordless ACR access for the API Container App. Gated behind
# create_managed_identities (default false); its validations in variables.tf
# guarantee create_resource_group and create_acr are also true whenever this is
# enabled, so module.resource_group[0] and module.acr[0] are always safe here.
module "managed_identities" {
  source = "../../modules/managed_identities"
  count  = var.create_managed_identities ? 1 : 0

  name                = local.api_identity_name
  resource_group_name = module.resource_group[0].name
  location            = module.resource_group[0].location
  acr_id              = module.acr[0].id
  tags                = local.common_tags
}

# Block 4.16 — Azure Database for PostgreSQL Flexible Server. Gated behind
# create_postgres (default false); its validations in variables.tf guarantee
# create_resource_group and create_key_vault are also true whenever this is enabled.
module "postgres_flexible" {
  source = "../../modules/postgres_flexible"
  count  = var.create_postgres ? 1 : 0

  server_name         = local.postgres_server_name
  database_name       = local.postgres_database_name
  resource_group_name = module.resource_group[0].name
  location            = coalesce(var.postgres_location, module.resource_group[0].location)

  administrator_login           = var.postgres_administrator_login
  postgres_version              = var.postgres_version
  sku_name                      = var.postgres_sku_name
  storage_mb                    = var.postgres_storage_mb
  backup_retention_days         = var.postgres_backup_retention_days
  public_network_access_enabled = var.postgres_public_network_access_enabled
  allowed_firewall_rules        = var.postgres_allowed_firewall_rules

  tags = local.common_tags
}

# Block 4.14 — Azure Key Vault with RBAC for API secrets. Gated behind
# create_key_vault (default false); its validations in variables.tf guarantee
# create_resource_group and create_managed_identities are also true whenever this
# is enabled, so module.resource_group[0] and module.managed_identities[0] are
# always safe here.
module "key_vault" {
  source = "../../modules/key_vault"
  count  = var.create_key_vault ? 1 : 0

  name                      = local.key_vault_name
  resource_group_name       = module.resource_group[0].name
  location                  = module.resource_group[0].location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  api_identity_principal_id = module.managed_identities[0].principal_id

  sku_name                   = var.key_vault_sku_name
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
  purge_protection_enabled   = var.key_vault_purge_protection_enabled
  secrets                    = local.api_key_vault_secrets
  tags                       = local.common_tags
}

# Block 4.13 — AcrPull is granted via azurerm_role_assignment, but Azure AD/RBAC
# propagation is eventually consistent: the role assignment API call can report
# "complete" before the permission is actually usable for an image pull. The
# Container App module only references module.managed_identities[0].id (the
# identity resource), so Terraform has no implicit dependency on the role
# assignment and creates both in parallel — the first apply attempt hit exactly
# this race (ContainerAppOperationError: unable to pull image using Managed
# identity). This explicit wait after the full managed_identities module
# (identity + AcrPull role assignment) gives RBAC time to propagate before the
# Container App tries to pull the image.
resource "time_sleep" "wait_for_acr_pull_propagation" {
  count = var.create_container_apps ? 1 : 0

  depends_on      = [module.managed_identities]
  create_duration = "60s"
}

# Block 4.12 — the FitTrack AI API itself. Gated behind create_container_apps
# (default false); its validations in variables.tf guarantee create_resource_group,
# create_acr, create_container_apps_environment, and create_managed_identities are
# also true whenever this is enabled, so every module reference below is safe.
module "container_apps" {
  source = "../../modules/container_apps"
  count  = var.create_container_apps ? 1 : 0

  depends_on = [
    time_sleep.wait_for_acr_pull_propagation,
    module.key_vault,
  ]

  name                         = local.container_app_api_name
  resource_group_name          = module.resource_group[0].name
  container_app_environment_id = module.container_apps_environment[0].id
  image                        = "${module.acr[0].login_server}/fittrack-api:${var.api_image_tag}"
  registry_server              = module.acr[0].login_server
  identity_id                  = module.managed_identities[0].id
  cpu                          = var.api_cpu
  memory                       = var.api_memory
  min_replicas                 = var.api_min_replicas
  max_replicas                 = var.api_max_replicas
  target_port                  = var.api_target_port
  tags                         = local.common_tags

  env_vars = merge(
    { AI_PROVIDER = var.api_ai_provider },
    var.api_ai_provider == "azure" && var.api_azure_openai_api_version != "" ? {
      AZURE_OPENAI_API_VERSION = var.api_azure_openai_api_version
    } : {},
    var.create_key_vault ? {} : {
      JWT_SECRET_KEY = "dev-only-placeholder-change-before-prod"
      DATABASE_URL   = "postgresql+psycopg://placeholder:placeholder@placeholder:5432/fittrack"
    }
  )

  secrets = var.create_key_vault ? merge(
    {
      jwt-secret-key = {
        key_vault_secret_id = module.key_vault[0].secret_ids["JWT-SECRET-KEY"]
        identity            = module.managed_identities[0].id
      }
      database-url = {
        key_vault_secret_id = module.key_vault[0].secret_ids["DATABASE-URL"]
        identity            = module.managed_identities[0].id
      }
    },
    var.api_ai_provider == "azure" && var.api_azure_openai_endpoint != "" ? {
      azure-openai-endpoint = {
        key_vault_secret_id = module.key_vault[0].secret_ids["AZURE-OPENAI-ENDPOINT"]
        identity            = module.managed_identities[0].id
      }
    } : {},
    var.api_ai_provider == "azure" && var.api_azure_openai_api_key != "" ? {
      azure-openai-api-key = {
        key_vault_secret_id = module.key_vault[0].secret_ids["AZURE-OPENAI-API-KEY"]
        identity            = module.managed_identities[0].id
      }
    } : {},
    var.api_ai_provider == "azure" && var.api_azure_openai_deployment != "" ? {
      azure-openai-deployment = {
        key_vault_secret_id = module.key_vault[0].secret_ids["AZURE-OPENAI-DEPLOYMENT"]
        identity            = module.managed_identities[0].id
      }
    } : {},
  ) : {}

  secret_env_vars = var.create_key_vault ? merge(
    {
      JWT_SECRET_KEY = { secret_name = "jwt-secret-key" }
      DATABASE_URL   = { secret_name = "database-url" }
    },
    var.api_ai_provider == "azure" && var.api_azure_openai_endpoint != "" ? {
      AZURE_OPENAI_ENDPOINT = { secret_name = "azure-openai-endpoint" }
    } : {},
    var.api_ai_provider == "azure" && var.api_azure_openai_api_key != "" ? {
      AZURE_OPENAI_API_KEY = { secret_name = "azure-openai-api-key" }
    } : {},
    var.api_ai_provider == "azure" && var.api_azure_openai_deployment != "" ? {
      AZURE_OPENAI_DEPLOYMENT = { secret_name = "azure-openai-deployment" }
    } : {},
  ) : {}
}
