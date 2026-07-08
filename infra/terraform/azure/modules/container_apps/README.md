# Module: container_apps

**Status:** implemented and applied in Block 4.13 — Key Vault secret wiring applied in Block 4.15.
Gated by `create_container_apps` (default `false`, set to `true` in
`terraform.container-app.example.tfvars` or `terraform.key-vault.example.tfvars`) in
`environments/dev`.

## Purpose

Provisions the FitTrack AI API Container App: image reference, ingress, scaling, environment
variables, and optional Key Vault-backed secrets — the Terraform equivalent of the manual
`az containerapp create` / `update` flow documented in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md#8-create-the-container-app).

Depends on `resource_group`, `acr` (image + registry server), `container_apps_environment`
(runtime), and `managed_identities` (passwordless `AcrPull`). When `create_key_vault=true` in the
environment, also depends on `module.key_vault` for secret IDs.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | From `local.container_app_api_name`. |
| `resource_group_name` | `string` | — | From `module.resource_group`. |
| `container_app_environment_id` | `string` | — | From `module.container_apps_environment`. |
| `image` | `string` | — | Full ACR image reference. |
| `registry_server` | `string` | — | From `module.acr`'s `login_server`. |
| `identity_id` | `string` | — | From `module.managed_identities`'s `id`, used for `AcrPull` and Key Vault refs. |
| `cpu` | `number` | `0.25` | CPU cores allocated to the container. |
| `memory` | `string` | `"0.5Gi"` | Memory allocated to the container. |
| `min_replicas` | `number` | `0` | Minimum replicas — `0` allows scale-to-zero. |
| `max_replicas` | `number` | `1` | Maximum replicas. |
| `target_port` | `number` | `8000` | Port exposed by the FastAPI container. |
| `env_vars` | `map(string)` | `{}` | Plain (non-sensitive) environment variables. |
| `secrets` | `map(object)` | `{}` | Container App secrets — direct values or Key Vault references (sensitive). |
| `secret_env_vars` | `map(object)` | `{}` | Env vars sourced from Container App secrets via `secret_name`. |
| `tags` | `map(string)` | `{}` | Common tags. |

### Secret object shape

Each entry in `secrets` supports:

- **Key Vault reference (preferred):** `key_vault_secret_id` + `identity` (managed identity resource ID)
- **Direct value (intermediate fallback):** `value` only

When `key_vault_secret_id` and `identity` are set, `value` is ignored by the provider.

### Secret env var wiring

`secret_env_vars` maps env var names to `{ secret_name = "..." }`, equivalent to Azure's
`secretref:` syntax. Example:

```hcl
secrets = {
  jwt-secret-key = {
    key_vault_secret_id = module.key_vault[0].secret_ids["JWT-SECRET-KEY"]
    identity            = module.managed_identities[0].id
  }
}

secret_env_vars = {
  JWT_SECRET_KEY = { secret_name = "jwt-secret-key" }
}
```

## Outputs

| Name | Description |
|---|---|
| `id` | Container App resource ID. |
| `name` | Container App name. |
| `latest_revision_fqdn` | FQDN of the latest revision. |
| `url` | `"https://${latest_revision_fqdn}"` — public URL for `GET /health`. |

## Notes

This module creates **only** `azurerm_container_app`, with:

- `revision_mode = "Single"`
- `identity { type = "UserAssigned" }`
- `registry` block authenticated via managed identity
- External `ingress` with 100% traffic to the latest revision
- Top-level `dynamic "secret"` blocks for Key Vault references or inline values
- Container `dynamic "env"` for plain vars and secret-backed vars

### Block 4.15 (current live deployment with Key Vault)

With `create_key_vault=true` (`terraform.key-vault.example.tfvars`), the Container App consumes
`JWT_SECRET_KEY` and `DATABASE_URL` via Key Vault-backed secret references. `AI_PROVIDER=fake`
remains a plain env var. Demo placeholder secret values live in Key Vault — not production-ready.

Health endpoint (canonical FQDN):

```text
https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health
```

Out of scope: Container App Jobs, Dapr, custom domains, certificates. Alembic migrations remain
a separate step, never run at container startup.

## Current deployed API

Container App:

```text
ca-fittrack-ai-api-dev
```

Image:

```text
acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.13-amd64
```

Health endpoint:

```text
https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health
```

## Current limitations

Demo/dev deployment. Secret values in Key Vault are placeholders. Real PostgreSQL and
production-grade secrets come in Block 4.16+.
