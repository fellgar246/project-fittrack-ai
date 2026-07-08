variable "name" {
  description = "Name of the Azure Key Vault."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Resource Group where Key Vault will be created."
  type        = string
}

variable "location" {
  description = "Azure region where Key Vault will be created."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID."
  type        = string
}

variable "api_identity_principal_id" {
  description = "Principal ID of the API managed identity that will read secrets."
  type        = string
}

variable "sku_name" {
  description = "SKU name for Key Vault."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be either standard or premium."
  }
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention period in days."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "purge_protection_enabled" {
  description = "Whether purge protection is enabled."
  type        = bool
  default     = false
}

variable "secrets" {
  description = "Map of secret names and values to create in Key Vault. Use only demo placeholders in example files."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to Key Vault resources."
  type        = map(string)
  default     = {}
}
