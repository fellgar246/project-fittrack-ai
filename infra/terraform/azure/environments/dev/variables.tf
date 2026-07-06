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
  description = "Whether to create the Azure Container Registry. Requires create_resource_group=true."
  default     = false

  validation {
    condition     = !var.create_acr || var.create_resource_group
    error_message = "create_acr=true requires create_resource_group=true."
  }
}

variable "acr_sku" {
  type        = string
  description = "SKU for the Azure Container Registry."
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be one of: Basic, Standard, Premium."
  }
}

variable "acr_admin_enabled" {
  type        = bool
  description = "Whether to enable the ACR admin user. Should remain false in favor of managed identity based access."
  default     = false
}

variable "unique_suffix" {
  type        = string
  description = "Optional suffix used to help make globally-scoped Azure resource names (like ACR) unique."
  default     = ""

  validation {
    condition     = var.unique_suffix == "" || can(regex("^[a-z0-9]{3,8}$", var.unique_suffix))
    error_message = "unique_suffix must be empty or 3 to 8 lowercase alphanumeric characters."
  }
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
  description = "Whether to create the Container Apps environment. Requires create_resource_group=true and create_monitoring=true."
  default     = false

  validation {
    condition     = !var.create_container_apps_environment || var.create_resource_group
    error_message = "create_container_apps_environment=true requires create_resource_group=true."
  }

  validation {
    condition     = !var.create_container_apps_environment || var.create_monitoring
    error_message = "create_container_apps_environment=true requires create_monitoring=true."
  }
}

variable "create_container_apps" {
  type        = bool
  description = "Whether to create the API Container App. Planned for a future block (modules/container_apps is currently a placeholder)."
  default     = false
}

variable "create_monitoring" {
  type        = bool
  description = "Whether to create the Log Analytics workspace. Requires create_resource_group=true."
  default     = false

  validation {
    condition     = !var.create_monitoring || var.create_resource_group
    error_message = "create_monitoring=true requires create_resource_group=true."
  }
}

variable "log_analytics_sku" {
  type        = string
  description = "SKU for the Log Analytics Workspace."
  default     = "PerGB2018"

  validation {
    condition     = contains(["Free", "PerGB2018"], var.log_analytics_sku)
    error_message = "log_analytics_sku must be one of: Free, PerGB2018."
  }
}

variable "log_analytics_retention_in_days" {
  type        = number
  description = "Log Analytics Workspace retention in days."
  default     = 30

  validation {
    condition     = var.log_analytics_retention_in_days >= 30 && var.log_analytics_retention_in_days <= 730
    error_message = "log_analytics_retention_in_days must be between 30 and 730."
  }
}
