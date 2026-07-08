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
  description = "Whether to create Azure Key Vault and related secret access configuration."
  default     = false

  validation {
    condition     = !var.create_key_vault || var.create_resource_group
    error_message = "create_key_vault=true requires create_resource_group=true."
  }

  validation {
    condition     = !var.create_key_vault || var.create_managed_identities
    error_message = "create_key_vault=true requires create_managed_identities=true."
  }
}

variable "key_vault_sku_name" {
  description = "SKU for Azure Key Vault."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku_name)
    error_message = "key_vault_sku_name must be either standard or premium."
  }
}

variable "key_vault_soft_delete_retention_days" {
  description = "Soft delete retention period for Key Vault in days."
  type        = number
  default     = 7

  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "key_vault_soft_delete_retention_days must be between 7 and 90."
  }
}

variable "key_vault_purge_protection_enabled" {
  description = "Whether purge protection is enabled for Key Vault."
  type        = bool
  default     = false
}

variable "api_jwt_secret_key" {
  description = "JWT secret key for the API. Use only local tfvars or safe demo placeholder values."
  type        = string
  sensitive   = true
  default     = "dev-only-placeholder-change-before-prod"
}

variable "api_database_url" {
  description = "Database URL for the API. Placeholder until Azure PostgreSQL is created."
  type        = string
  sensitive   = true
  default     = "postgresql+psycopg://placeholder:placeholder@placeholder:5432/fittrack_ai"
}

variable "create_managed_identities" {
  type        = bool
  description = "Whether to create the API managed identity and its AcrPull role assignment. Requires create_resource_group=true and create_acr=true."
  default     = false

  validation {
    condition     = !var.create_managed_identities || var.create_resource_group
    error_message = "create_managed_identities=true requires create_resource_group=true."
  }

  validation {
    condition     = !var.create_managed_identities || var.create_acr
    error_message = "create_managed_identities=true requires create_acr=true."
  }
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
  description = "Whether to create the API Container App. Requires create_resource_group=true, create_acr=true, create_container_apps_environment=true, and create_managed_identities=true."
  default     = false

  validation {
    condition     = !var.create_container_apps || var.create_resource_group
    error_message = "create_container_apps=true requires create_resource_group=true."
  }

  validation {
    condition     = !var.create_container_apps || var.create_acr
    error_message = "create_container_apps=true requires create_acr=true."
  }

  validation {
    condition     = !var.create_container_apps || var.create_container_apps_environment
    error_message = "create_container_apps=true requires create_container_apps_environment=true."
  }

  validation {
    condition     = !var.create_container_apps || var.create_managed_identities
    error_message = "create_container_apps=true requires create_managed_identities=true."
  }
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

variable "api_image_tag" {
  type        = string
  description = "Docker image tag for the FitTrack AI API, published to the ACR by Block 4.9."
  default     = "block-4.9"
}

variable "api_cpu" {
  type        = number
  description = "CPU cores allocated to the API Container App."
  default     = 0.25
}

variable "api_memory" {
  type        = string
  description = "Memory allocated to the API Container App."
  default     = "0.5Gi"
}

variable "api_min_replicas" {
  type        = number
  description = "Minimum number of API Container App replicas."
  default     = 0
}

variable "api_max_replicas" {
  type        = number
  description = "Maximum number of API Container App replicas."
  default     = 1
}

variable "api_target_port" {
  type        = number
  description = "Container port exposed by the FastAPI API."
  default     = 8000
}
