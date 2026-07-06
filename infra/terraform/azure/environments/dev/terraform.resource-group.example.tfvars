# Preview creation of ONLY the Resource Group.
#
# Usage:
#   az login                # or export ARM_SUBSCRIPTION_ID
#   terraform plan -var-file="terraform.resource-group.example.tfvars"
#
# No secrets here. Do NOT run `terraform apply` unless explicitly authorized.
# subscription_id is resolved from ARM_SUBSCRIPTION_ID / `az login`, not hardcoded
# (see terraform.tfvars.example and providers.tf).

project_name = "fittrack-ai"
environment  = "dev"
location     = "eastus"
owner        = "felipe"
cost_center  = "portfolio"

create_resource_group = true

create_acr                        = false
create_key_vault                  = false
create_managed_identities         = false
create_networking                 = false
create_postgres                   = false
create_container_apps_environment = false
create_container_apps             = false
create_monitoring                 = false
