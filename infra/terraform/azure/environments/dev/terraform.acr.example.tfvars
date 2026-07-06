# Preview creation of the Resource Group + Azure Container Registry.
#
# Usage:
#   az login                # or export ARM_SUBSCRIPTION_ID
#   terraform plan -var-file="terraform.acr.example.tfvars"
#
# No secrets here. Do NOT run `terraform apply` in Block 4.7.
# subscription_id is resolved from ARM_SUBSCRIPTION_ID / `az login`, not hardcoded
# (see terraform.tfvars.example and providers.tf).

project_name = "fittrack-ai"
environment  = "dev"
location     = "eastus"
owner        = "felipe"
cost_center  = "portfolio"

# Optional suffix to help make the globally-scoped ACR name unique.
unique_suffix = "dev01"

create_resource_group = true
create_acr            = true

create_key_vault                  = false
create_managed_identities         = false
create_networking                 = false
create_postgres                   = false
create_container_apps_environment = false
create_container_apps             = false
create_monitoring                 = false

acr_sku           = "Basic"
acr_admin_enabled = false
