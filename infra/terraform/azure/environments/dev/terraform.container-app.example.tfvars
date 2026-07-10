# Preview creation of the API managed identity + AcrPull role assignment + API Container App.
#
# Usage:
#   az login                # or export ARM_SUBSCRIPTION_ID
#   terraform plan -var-file="terraform.container-app.example.tfvars"
#
# No secrets here. Do NOT run `terraform apply` in Block 4.12.
# subscription_id is resolved from ARM_SUBSCRIPTION_ID / `az login`, not hardcoded
# (see terraform.tfvars.example and providers.tf).
#
# Resource Group, ACR, Log Analytics Workspace, and Container Apps Environment already
# exist in state (Blocks 4.6, 4.8, and 4.11), so this plan should only propose the three
# new resources for this block: the user-assigned managed identity, its AcrPull role
# assignment, and the API Container App.

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

create_managed_identities = true
create_container_apps     = true

create_key_vault  = false
create_networking = false
create_postgres   = false

acr_sku           = "Basic"
acr_admin_enabled = false

log_analytics_sku               = "PerGB2018"
log_analytics_retention_in_days = 30

# Block 4.9 pushed a linux/arm64 image (built on Apple Silicon without
# --platform), which Azure Container Apps rejects (requires linux/amd64).
# Block 4.13 rebuilt and pushed a linux/amd64 image under this tag.
api_image_tag    = "block-4.23-amd64"
api_cpu          = 0.25
api_memory       = "0.5Gi"
api_min_replicas = 0
api_max_replicas = 1
api_target_port  = 8000
