variable "server_name" {
  description = "Name of the PostgreSQL Flexible Server."
  type        = string
}

variable "database_name" {
  description = "Name of the application database."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Resource Group where PostgreSQL will be created."
  type        = string
}

variable "location" {
  description = "Azure region where PostgreSQL will be created."
  type        = string
}

variable "administrator_login" {
  description = "PostgreSQL administrator username."
  type        = string
  default     = "fittrackadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{2,30}$", var.administrator_login))
    error_message = "administrator_login must start with a letter and use letters, numbers, or underscores."
  }
}

variable "postgres_version" {
  description = "PostgreSQL version."
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "SKU name for PostgreSQL Flexible Server."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Backup retention in days."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "zone" {
  description = "Availability zone. Null lets Azure choose."
  type        = string
  default     = null
}

variable "public_network_access_enabled" {
  description = "Whether public network access is enabled."
  type        = bool
  default     = true
}

variable "allowed_firewall_rules" {
  description = "Firewall rules for PostgreSQL public access."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to PostgreSQL resources."
  type        = map(string)
  default     = {}
}
