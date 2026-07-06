variable "workspace_name" {
  type        = string
  description = "Name of the Log Analytics Workspace."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group where the workspace will be created."
}

variable "location" {
  type        = string
  description = "Azure region where the workspace will be created."
}

variable "sku" {
  type        = string
  description = "SKU for the Log Analytics Workspace."
  default     = "PerGB2018"

  validation {
    condition     = contains(["Free", "PerGB2018"], var.sku)
    error_message = "sku must be one of: Free, PerGB2018."
  }
}

variable "retention_in_days" {
  type        = number
  description = "Log retention in days."
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Log Analytics Workspace."
  default     = {}
}
