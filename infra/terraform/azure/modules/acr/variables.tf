variable "name" {
  type        = string
  description = "Name of the Azure Container Registry."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group where the ACR will be created."
}

variable "location" {
  type        = string
  description = "Azure region where the ACR will be created."
}

variable "sku" {
  type        = string
  description = "SKU for the Azure Container Registry."
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be one of: Basic, Standard, Premium."
  }
}

variable "admin_enabled" {
  type        = bool
  description = "Whether the admin user is enabled for the Azure Container Registry."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Azure Container Registry."
  default     = {}
}
