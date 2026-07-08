resource "azurerm_key_vault" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = var.sku_name
  rbac_authorization_enabled  = true
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled
  tags                       = var.tags
}

resource "azurerm_role_assignment" "api_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.api_identity_principal_id
}

resource "azurerm_key_vault_secret" "this" {
  for_each = nonsensitive(var.secrets)

  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [
    azurerm_role_assignment.api_secrets_user,
  ]
}
