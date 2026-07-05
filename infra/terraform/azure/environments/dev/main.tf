# Block 4.4 — modular architecture alignment.
#
# The resource group now comes from modules/resource_group instead of being
# declared directly here. It stays gated behind create_resource_group (default
# false), so this block still creates zero real Azure resources by default.
# Enabling it (create_resource_group = true) and running the first real
# `terraform apply` is deferred to Block 4.5. Every other Azure service
# (ACR, Key Vault, Postgres, Container Apps, ...) will be its own module under
# modules/, wired here behind its own create_* flag once implemented — see
# modules/README.md for the full planned module flow.

module "resource_group" {
  source = "../../modules/resource_group"
  count  = var.create_resource_group ? 1 : 0

  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}
