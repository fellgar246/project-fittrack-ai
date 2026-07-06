variable "name" {
  type        = string
  description = "Name of the Azure Container Apps Environment."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group where the environment will be created."
}

variable "location" {
  type        = string
  description = "Azure region where the environment will be created."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics Workspace used for the environment's logs."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Container Apps Environment."
  default     = {}
}
