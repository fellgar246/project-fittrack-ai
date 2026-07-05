# Module: key_vault (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.8.

## Purpose

Provision an Azure Key Vault to hold FitTrack AI secrets (`DATABASE_URL`,
`JWT_SECRET_KEY`, `AZURE_OPENAI_API_KEY`, etc.) so Container Apps can reference
them instead of storing raw secret values in Container App secrets directly.

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `name` | `string` | Key Vault name. |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `location` | `string` | From `module.resource_group`. |
| `sku_name` | `string` | Defaults to `"standard"`. |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `id` | Key Vault resource ID. |
| `vault_uri` | Used by app/services to read secrets. |
| `name` | Key Vault name. |

## Notes

Enabled by `var.create_key_vault` (default `false`). Depends on `resource_group`
and `managed_identities` (RBAC access policy grants). No secret **values** are
ever hardcoded in Terraform — only the vault and its access policies.
