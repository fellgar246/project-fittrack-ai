# Example file to preview creation of Azure PostgreSQL Flexible Server.
#
# Usage:
#   terraform plan -var-file="terraform.postgres.example.tfvars"
#
# Block 4.17 authorizes terraform apply with this file.
# Do not include real secrets in this file.

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
create_postgres   = true
create_networking = false

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

# Existing demo/dev placeholders until DATABASE_URL is replaced after PostgreSQL apply.
api_jwt_secret_key = "dev-only-placeholder-change-before-prod"
api_database_url   = "postgresql+psycopg://placeholder:placeholder@placeholder:5432/fittrack_ai"

postgres_administrator_login           = "fittrackadmin"
postgres_version                       = "16"
postgres_sku_name                      = "B_Standard_B1ms"
postgres_storage_mb                    = 32768
postgres_backup_retention_days         = 7
postgres_public_network_access_enabled = true
postgres_location                      = "centralus"

# Default: no external firewall rules.
# Add your current public IP only when you intentionally need direct local access.
postgres_allowed_firewall_rules = {}
