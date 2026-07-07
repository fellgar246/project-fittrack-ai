variable "name" {
  type        = string
  description = "Name of the user-assigned managed identity."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group where the identity will be created."
}

variable "location" {
  type        = string
  description = "Azure region where the identity will be created."
}

variable "acr_id" {
  type        = string
  description = "Resource ID of the Azure Container Registry used as the scope for the AcrPull role assignment."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the managed identity."
  default     = {}
}
