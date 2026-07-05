# Module: monitoring (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.11.

## Purpose

Provision the Log Analytics workspace (and, later, Application Insights) used
for Container Apps logs and metrics — the Terraform equivalent of the workspace
Azure auto-creates today when running `az containerapp env create` manually.

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `name` | `string` | From `local.log_analytics_workspace`. |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `location` | `string` | From `module.resource_group`. |
| `retention_in_days` | `number` | Defaults to a low value (e.g. `30`) to control cost. |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `workspace_id` | Consumed by `container_apps_environment`. |
| `workspace_key` | Shared key, sensitive, used to connect the environment. |

## Notes

Enabled by `var.create_monitoring` (default `false`). Depends on `resource_group`.
Application Insights integration is explicitly out of scope until a future block
(see `docs/azure-container-apps-deploy.md` known limitations).
