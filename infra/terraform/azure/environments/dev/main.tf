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
