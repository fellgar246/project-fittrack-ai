# Module: container_apps_environment (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.12.

## Purpose

Provision the Azure Container Apps environment (and its Log Analytics workspace,
unless supplied by the `monitoring` module) that hosts the FitTrack AI API
Container App, replacing the manual `az containerapp env create` step in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md#7-create-the-container-apps-environment).

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `name` | `string` | From `local.container_app_env_name`. |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `location` | `string` | From `module.resource_group`. |
| `log_analytics_workspace_id` | `string` | From `monitoring` module. |
| `infrastructure_subnet_id` | `string` | Optional; from `networking`, for private environments. |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `id` | Environment resource ID, consumed by `container_apps`. |
| `default_domain` | Base domain for app FQDNs. |

## Notes

Enabled by `var.create_container_apps_environment` (default `false`). Depends on
`resource_group`, `monitoring`, and optionally `networking`.
