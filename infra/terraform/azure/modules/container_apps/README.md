# Module: container_apps

**Status:** implemented (Block 4.12) — gated by `create_container_apps` (default
`false`) in `environments/dev`. No `terraform apply` has been run for this module
yet; only `terraform plan` has been validated.

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

**Planning-only placeholders:** `environments/dev/main.tf` wires this module with
`AI_PROVIDER=fake`, and placeholder values for `JWT_SECRET_KEY` and `DATABASE_URL`.
These are visible in plan output but are **not created in Azure** because this
block does not run `terraform apply`. They are acceptable only as dev/demo
placeholders — a future block must move real secrets to Key Vault (via
`secretref:` env vars) before any real `apply` of this module. `AI_PROVIDER=fake`
lets the API start without a live Azure OpenAI dependency, and no real PostgreSQL
exists yet, so an early deploy would only be expected to serve `GET /health`.

Out of scope for this module: Container App Jobs, Dapr, custom domains,
certificates, and secret-backed env vars (`secrets` block) — deferred until Key
Vault exists. Alembic migrations remain a separate step, never run at container
startup.

## Block 4.12 scope

Module implemented and wired behind `create_container_apps` (default `false`).
Only `terraform plan` was validated — see [`../../README.md`](../../README.md) for
the plan scenario. `terraform apply` is deferred to a future block.
