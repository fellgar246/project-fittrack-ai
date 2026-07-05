# Module: acr (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.6.

## Purpose

Provision the Azure Container Registry (ACR) that stores the FitTrack AI API
image, replacing the manual `az acr create` step documented in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md).

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `name` | `string` | ACR name (alphanumeric only, globally unique — see `local.acr_name`). |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `location` | `string` | From `module.resource_group`. |
| `sku` | `string` | Defaults to `"Basic"`. |
| `admin_enabled` | `bool` | Defaults to `false` — pull access is via managed identity, not admin credentials. |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `id` | ACR resource ID (used for `AcrPull` role assignments). |
| `login_server` | e.g. `acrfittrackaidev.azurecr.io`. |
| `name` | ACR name. |

## Notes

Enabled by `var.create_acr` (default `false`) in `environments/dev`. Depends on
`resource_group`. Pull access from Container Apps will use the `managed_identities`
module's identity, not `admin_enabled`.
