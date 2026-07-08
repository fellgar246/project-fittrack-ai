variable "name" {
  type        = string
  description = "Name of the Container App."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group where the Container App will be created."
}

variable "container_app_environment_id" {
  type        = string
  description = "Resource ID of the Azure Container Apps Environment."
}

variable "image" {
  type        = string
  description = "Full container image reference, including registry and tag."
}

variable "registry_server" {
  type        = string
  description = "Login server of the Azure Container Registry hosting the image."
}

variable "identity_id" {
  type        = string
  description = "Resource ID of the user-assigned managed identity used to pull the image from the private registry."
}

variable "cpu" {
  type        = number
  description = "CPU cores allocated to the container."
  default     = 0.25
}

variable "memory" {
  type        = string
  description = "Memory allocated to the container."
  default     = "0.5Gi"
}

variable "min_replicas" {
  type        = number
  description = "Minimum number of replicas."
  default     = 0
}

variable "max_replicas" {
  type        = number
  description = "Maximum number of replicas."
  default     = 1
}

variable "target_port" {
  type        = number
  description = "Port exposed by the container for ingress."
  default     = 8000
}

variable "env_vars" {
  type        = map(string)
  description = "Environment variables passed to the container."
  default     = {}
}

variable "secrets" {
  description = "Container App secrets. Values may be direct values or Key Vault references depending on configuration."
  type = map(object({
    value               = optional(string)
    key_vault_secret_id = optional(string)
    identity            = optional(string)
  }))
  default   = {}
  sensitive = true
}

variable "secret_env_vars" {
  description = "Environment variables sourced from Container App secrets."
  type = map(object({
    secret_name = string
  }))
  default = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Container App."
  default     = {}
}
