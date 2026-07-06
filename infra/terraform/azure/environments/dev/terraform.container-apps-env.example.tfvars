# Preview creation of Resource Group + ACR + Monitoring + Container Apps Environment.
#
# Usage:
#   az login                # or export ARM_SUBSCRIPTION_ID
#   terraform plan -var-file="terraform.container-apps-env.example.tfvars"
#
# No secrets here. Do NOT run `terraform apply` in Block 4.10.
# subscription_id is resolved from ARM_SUBSCRIPTION_ID / `az login`, not hardcoded
# (see terraform.tfvars.example and providers.tf).
#
# Resource Group and ACR already exist in state (Blocks 4.6 and 4.8), so this plan
# should only propose the two new resources for this block: Log Analytics Workspace
# and Container Apps Environment.

project_name = "fittrack-ai"
environment  = "dev"
location     = "eastus"
owner        = "felipe"
cost_center  = "portfolio"

# Optional suffix to help make the globally-scoped ACR name unique.
unique_suffix = "dev01"

create_resource_group = true
create_acr            = true

create_monitoring                 = true
create_container_apps_environment = true

create_key_vault          = false
create_managed_identities = false
create_networking         = false
create_postgres           = false
create_container_apps     = false

acr_sku           = "Basic"
acr_admin_enabled = false

log_analytics_sku               = "PerGB2018"
log_analytics_retention_in_days = 30
