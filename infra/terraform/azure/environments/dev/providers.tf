provider "azurerm" {
  features {}

  # azurerm v4 requires a subscription_id. Leave var.subscription_id as null and
  # export ARM_SUBSCRIPTION_ID (or run `az login` / `az account set`) instead of
  # hardcoding a subscription ID here.
  subscription_id = var.subscription_id
}
