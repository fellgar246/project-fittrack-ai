# Module: container_apps

**Status:** implemented and applied in Block 4.13 — gated by `create_container_apps`
(default `false`, set to `true` in `terraform.container-app.example.tfvars`) in
`environments/dev`. `terraform apply` has been run and the Container App is live.

## Purpose

Provisions the FitTrack AI API Container App: image reference, ingress, scaling,
and env vars — the Terraform equivalent of the manual `az containerapp create` /
`update` flow documented in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md#8-create-the-container-app).

Depends on `resource_group`, `acr` (image + registry server), `container_apps_environment`
(runtime), and `managed_identities` (passwordless `AcrPull`). Enabling
`create_container_apps` requires `create_resource_group=true`, `create_acr=true`,
`create_container_apps_environment=true`, and `create_managed_identities=true`
(enforced by validations on `create_container_apps` in `environments/dev/variables.tf`).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | From `local.container_app_api_name`. |
| `resource_group_name` | `string` | — | From `module.resource_group`. |
| `container_app_environment_id` | `string` | — | From `module.container_apps_environment`. |
| `image` | `string` | — | Full ACR image reference: `"${module.acr[0].login_server}/fittrack-api:${var.api_image_tag}"`. |
| `registry_server` | `string` | — | From `module.acr`'s `login_server`. |
| `identity_id` | `string` | — | From `module.managed_identities`'s `id`, used for `AcrPull`. |
| `cpu` | `number` | `0.25` | CPU cores allocated to the container. |
| `memory` | `string` | `"0.5Gi"` | Memory allocated to the container. |
| `min_replicas` | `number` | `0` | Minimum replicas — `0` allows scale-to-zero. |
| `max_replicas` | `number` | `1` | Maximum replicas. |
| `target_port` | `number` | `8000` | Port exposed by the FastAPI container. |
| `env_vars` | `map(string)` | `{}` | Environment variables passed to the container. |
| `tags` | `map(string)` | `{}` | Common tags. |

## Outputs

| Name | Description |
|---|---|
| `id` | Container App resource ID. |
| `name` | Container App name. |
| `latest_revision_fqdn` | FQDN of the latest revision. Known only after `apply`. |
| `url` | `"https://${latest_revision_fqdn}"` — public URL for `GET /health`. |

## Notes

This module creates **only** `azurerm_container_app`, with `revision_mode = "Single"`,
`identity { type = "UserAssigned" }`, a `registry` block authenticated via that
identity (no admin username/password), external `ingress` with 100% traffic to the
latest revision, and a single `container` block with a `dynamic "env"` over
`var.env_vars`.

**Dev/demo placeholders (now applied):** `environments/dev/main.tf` wires this
module with `AI_PROVIDER=fake`, and placeholder values for `JWT_SECRET_KEY` and
`DATABASE_URL`. As of Block 4.13 these values **are live in Azure** as plain
Container App env vars — they are acceptable only for validating `GET /health` on
a dev/demo deployment, not for real application flows. A future block (4.14) must
move real secrets to Key Vault (via `secretref:` env vars) before enabling any
real database or AI traffic. `AI_PROVIDER=fake` lets the API start without a live
Azure OpenAI dependency, and no real PostgreSQL exists yet.

Out of scope for this module: Container App Jobs, Dapr, custom domains,
certificates, and secret-backed env vars (`secrets` block) — deferred until Key
Vault exists. Alembic migrations remain a separate step, never run at container
startup.

## Status

Implemented and applied in Block 4.13.

This module currently deploys the FitTrack AI FastAPI backend as an Azure
Container App using:

- external ingress
- private ACR image
- user-assigned managed identity
- AcrPull-based registry authentication
- dynamic environment variables
- single-revision mode

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

Validation:

```json
{"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

## Current limitations

This is a demo/dev deployment.

The current Container App still uses placeholder environment values for:

- `DATABASE_URL`
- `JWT_SECRET_KEY`
- `AI_PROVIDER=fake`

These values are acceptable only for validating `/health`.

Before enabling real API flows, the project must add:

- Key Vault
- real secret management
- Azure PostgreSQL
- secure `DATABASE_URL`
- production-grade JWT secret handling
