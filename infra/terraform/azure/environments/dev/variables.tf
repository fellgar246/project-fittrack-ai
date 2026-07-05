variable "project_name" {
  type        = string
  description = "Project name used for resource naming."
  default     = "fittrack-ai"

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "eastus"

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "owner" {
  type        = string
  description = "Owner or maintainer of the resources."
}

variable "cost_center" {
  type        = string
  description = "Cost tracking label."
  default     = "portfolio"
}

variable "subscription_id" {
  type        = string
  description = <<-EOT
    Azure subscription ID. Leave as null and set the ARM_SUBSCRIPTION_ID
    environment variable (or rely on the active `az login` context) instead
    of hardcoding a subscription ID in tfvars.
  EOT
  default     = null
}

variable "create_resource_group" {
  type        = bool
  description = "Whether to create the Azure resource group via modules/resource_group. Kept false until an explicit apply is authorized (Block 4.5)."
  default     = false
}

variable "create_acr" {
  type        = bool
  description = "Whether to create the Azure Container Registry. Planned for a future block (modules/acr is currently a placeholder)."
  default     = false
}

variable "create_key_vault" {
  type        = bool
  description = "Whether to create the Key Vault. Planned for a future block (modules/key_vault is currently a placeholder)."
  default     = false
}

variable "create_managed_identities" {
  type        = bool
  description = "Whether to create managed identities. Planned for a future block (modules/managed_identities is currently a placeholder)."
  default     = false
}

variable "create_networking" {
  type        = bool
  description = "Whether to create the virtual network and subnets. Planned for a future block (modules/networking is currently a placeholder)."
  default     = false
}

variable "create_postgres" {
  type        = bool
  description = "Whether to create Azure Database for PostgreSQL Flexible Server. Planned for a future block (modules/postgres_flexible is currently a placeholder)."
  default     = false
}

variable "create_container_apps_environment" {
  type        = bool
  description = "Whether to create the Container Apps environment. Planned for a future block (modules/container_apps_environment is currently a placeholder)."
  default     = false
}

variable "create_container_apps" {
  type        = bool
  description = "Whether to create the API Container App. Planned for a future block (modules/container_apps is currently a placeholder)."
  default     = false
}

variable "create_monitoring" {
  type        = bool
  description = "Whether to create the Log Analytics workspace. Planned for a future block (modules/monitoring is currently a placeholder)."
  default     = false
}
