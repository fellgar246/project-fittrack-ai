variable "name" {
  type        = string
  description = "Globally unique storage account name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "container_name" {
  type        = string
  description = "Private blob container for progress photos."
  default     = "progress-photos"
}

variable "account_tier" {
  type        = string
  description = "Storage account tier."
  default     = "Standard"
}

variable "account_replication_type" {
  type        = string
  description = "Storage replication type."
  default     = "LRS"
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether the storage account endpoint is reachable over public networks."
  default     = true
}

variable "blob_soft_delete_retention_days" {
  type        = number
  description = "Blob soft delete retention in days."
  default     = 7
}

variable "container_soft_delete_retention_days" {
  type        = number
  description = "Container soft delete retention in days."
  default     = 7
}

variable "api_identity_principal_id" {
  type        = string
  description = "Principal ID of the API managed identity receiving blob RBAC."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the storage account."
  default     = {}
}
