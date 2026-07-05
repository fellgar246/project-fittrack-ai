# Module: container_apps (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.13.

## Purpose

Provision the FitTrack AI API Container App itself: image reference, ingress,
scaling, secrets, and env vars — the Terraform equivalent of the manual
`az containerapp create` / `secret set` / `update` flow documented in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md#8-create-the-container-app).

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `name` | `string` | From `local.container_app_api_name`. |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `container_apps_environment_id` | `string` | From `container_apps_environment`. |
| `image` | `string` | Full ACR image reference (registry + tag). |
| `registry_server` | `string` | From `acr` module's `login_server`. |
| `identity_id` | `string` | From `managed_identities`, used for `AcrPull`. |
| `target_port` | `number` | `8000`. |
| `cpu` / `memory` | `number` / `string` | `0.5` / `"1.0Gi"` — matches the manual deploy guide. |
| `min_replicas` / `max_replicas` | `number` | `0` / `1`. |
| `secrets` | `map(string)` | Sensitive values (e.g. `database-url`, `jwt-secret-key`). |
| `env_vars` | `map(string)` | Non-sensitive config + `secretref:` references. |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `fqdn` | Public HTTPS URL of the deployed API (`GET /health` target). |
| `id` | Container App resource ID. |

## Notes

Enabled by `var.create_container_apps` (default `false`). Depends on `acr`,
`container_apps_environment`, and `managed_identities`. Alembic migrations remain
a separate step, never run at container startup.
