# Example file to preview creation of Key Vault and Container App secret wiring.
#
# Usage:
#   terraform plan -var-file="terraform.key-vault.example.tfvars"
#
# Do not run terraform apply in Block 4.14.
# Do not include real production secrets in this file.

project_name  = "fittrack-ai"
environment   = "dev"
location      = "eastus"
unique_suffix = "dev01"

owner       = "felipe"
cost_center = "portfolio"

create_resource_group = true
create_acr            = true

create_monitoring                 = true
create_container_apps_environment = true

create_managed_identities = true
create_container_apps     = true

create_key_vault  = true
create_networking = false
create_postgres   = false

acr_sku           = "Basic"
acr_admin_enabled = false

log_analytics_sku               = "PerGB2018"
log_analytics_retention_in_days = 30

api_image_tag    = "block-4.13-amd64"
api_cpu          = 0.25
api_memory       = "0.5Gi"
api_min_replicas = 0
api_max_replicas = 1
api_target_port  = 8000

key_vault_sku_name                   = "standard"
key_vault_soft_delete_retention_days = 7
key_vault_purge_protection_enabled   = false

# Demo/dev placeholders only.
# These are safe placeholders, not production secrets.
api_jwt_secret_key = "dev-only-placeholder-change-before-prod"
api_database_url   = "postgresql+psycopg://placeholder:placeholder@placeholder:5432/fittrack_ai"
