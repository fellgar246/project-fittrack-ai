provider "azurerm" {
  features {}

  # Required when storage accounts disable shared key access; Terraform then uses
  # Azure AD for data-plane operations (e.g. validating blob service availability).
  storage_use_azuread = true

  # azurerm v4 requires a subscription_id. Leave var.subscription_id as null and
  # export ARM_SUBSCRIPTION_ID (or run `az login` / `az account set`) instead of
  # hardcoding a subscription ID here.
  subscription_id = var.subscription_id
}
