# Module: managed_identities (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.7.

## Purpose

Provision the user-assigned managed identity (or configure the Container App's
system-assigned identity) used for passwordless `AcrPull` access to the `acr`
module and, later, Key Vault access — matching the Managed Identity approach
already documented in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md#10-acr-pull-access-managed-identity).

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `name` | `string` | Identity name. |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `location` | `string` | From `module.resource_group`. |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `id` | Identity resource ID. |
| `principal_id` | Used for role assignments (e.g. `AcrPull`, Key Vault access). |
| `client_id` | Used by the Container App to reference the identity. |

## Notes

Enabled by `var.create_managed_identities` (default `false`). Consumed by `acr`
(role assignment), `key_vault` (access policy), and `container_apps` (identity
attached to the app).
