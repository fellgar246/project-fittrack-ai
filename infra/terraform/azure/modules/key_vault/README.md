# Module: key_vault

**Status:** implemented and applied in Block 4.15 — gated by `create_key_vault` (default `false`,
set to `true` in `terraform.key-vault.example.tfvars`) in `environments/dev`.

## Purpose

Provision an Azure Key Vault with RBAC authorization to hold FitTrack AI secrets
(`JWT-SECRET-KEY`, `DATABASE-URL`, and future Azure OpenAI keys) so the API Container App can
reference them via managed identity instead of storing raw secret values in plain environment
variables.

## Architecture

```text
Container App → Managed Identity → Key Vault (RBAC) → secret references
```

The API managed identity receives **`Key Vault Secrets User`** scoped to this vault — not
`Key Vault Administrator`, `Key Vault Secrets Officer`, or `Contributor`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | From `local.key_vault_name` (e.g. `kvfittrackaidevdev01`). |
| `resource_group_name` | `string` | — | From `module.resource_group`. |
| `location` | `string` | — | From `module.resource_group`. |
| `tenant_id` | `string` | — | From `data.azurerm_client_config.current.tenant_id`. |
| `api_identity_principal_id` | `string` | — | From `module.managed_identities`'s `principal_id`. |
| `sku_name` | `string` | `"standard"` | `standard` or `premium`. |
| `soft_delete_retention_days` | `number` | `7` | Between 7 and 90 days. |
| `purge_protection_enabled` | `bool` | `false` | Purge protection for the vault. |
| `secrets` | `map(string)` | `{}` | Secret names and values (sensitive). Demo placeholders only in example tfvars. |
| `tags` | `map(string)` | `{}` | Common tags. |

## Outputs

| Name | Description |
|---|---|
| `id` | Key Vault resource ID. |
| `name` | Key Vault name. |
| `vault_uri` | Key Vault URI. |
| `secret_names` | Names of secrets created — **never secret values**. |
| `secret_ids` | Map of secret names to secret IDs (sensitive; used for Container App wiring). |
| `api_secrets_user_role_assignment_id` | Role assignment ID for `Key Vault Secrets User`. |

## Resources created

- `azurerm_key_vault` with `rbac_authorization_enabled = true` (azurerm 4.x; replaces deprecated `enable_rbac_authorization`)
- `azurerm_role_assignment` — `Key Vault Secrets User` for the API managed identity
- `azurerm_key_vault_secret` — one per entry in `var.secrets` (uses `nonsensitive(var.secrets)` for `for_each` because secret values are sensitive)

## Initial secrets (demo/dev)

| Key Vault secret name | Maps to env var | Notes |
|---|---|---|
| `JWT-SECRET-KEY` | `JWT_SECRET_KEY` | Demo placeholder until production secret management |
| `DATABASE-URL` | `DATABASE_URL` | Placeholder until Azure PostgreSQL (Block 4.16+) |

Values are **demo-only placeholders**, not production-ready. Do not commit real secrets to
`.tfvars.example` files.

## Security decisions

1. **RBAC, not legacy access policies** — `enable_rbac_authorization = true` on the vault.
2. **Least privilege for the API** — only `Key Vault Secrets User`, no administrative roles.
3. **No secret values in outputs** — only names and IDs are exposed.
4. **Terraform runner permissions** — creating secrets via Terraform with RBAC requires the
   deployer (Block 4.15) to hold a role such as **Key Vault Secrets Officer** on the vault.
   The API identity alone cannot create secrets.

## Notes

Enabled by `var.create_key_vault` (default `false`). Requires `create_resource_group=true` and
`create_managed_identities=true` (enforced by validations in `environments/dev/variables.tf`).

Out of scope: private endpoints, diagnostic settings, certificates, keys, legacy access
policies, Azure OpenAI real configuration.

## Related blocks

- **Block 4.13** — Container App live with plain env var placeholders (acceptable for `/health` only).
- **Block 4.14** — Module implemented; plan validated, no apply.
- **Block 4.15** — Apply completed: Key Vault, secrets, and Container App secret wiring live in Azure.

## Rollback Key Vault secret wiring

To revert to the previous Container App demo state and destroy Key Vault resources:

```bash
cd infra/terraform/azure/environments/dev
terraform plan -var-file="terraform.container-app.example.tfvars"
terraform apply -var-file="terraform.container-app.example.tfvars"
```

Expected result: `Plan: 0 to add, 1 to change, 4 to destroy`. Do not run unless intentionally
rolling back Block 4.15.
