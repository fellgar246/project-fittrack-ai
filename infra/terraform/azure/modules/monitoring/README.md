# Module: monitoring

**Status:** implemented and applied (Block 4.11) — gated by `create_monitoring` (default
`false` in example tfvars, set to `true` in `terraform.container-apps-env.example.tfvars`) in
`environments/dev`. The real Log Analytics Workspace (`log-fittrack-ai-dev`) exists in Azure.

## Purpose

Provisions the Log Analytics Workspace used for Azure Container Apps logs and metrics —
the Terraform equivalent of the workspace Azure auto-creates when running
`az containerapp env create` manually. Consumed by `container_apps_environment`.

Depends on `resource_group`: it takes that module's `name`/`location` outputs as inputs.
Enabling `create_monitoring` requires `create_resource_group=true` (enforced by a
validation on `create_monitoring` in `environments/dev/variables.tf`).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `workspace_name` | `string` | — | From `local.log_analytics_workspace`. |
| `resource_group_name` | `string` | — | From `module.resource_group`. |
| `location` | `string` | — | From `module.resource_group`. |
| `sku` | `string` | `"PerGB2018"` | One of `Free`, `PerGB2018`. `PerGB2018` is the standard pay-as-you-go tier. |
| `retention_in_days` | `number` | `30` | Between 30 and 730. 30 days keeps cost low for dev/portfolio. |
| `tags` | `map(string)` | `{}` | Common tags. |

## Outputs

| Name | Description |
|---|---|
| `id` | Workspace resource ID — consumed by `container_apps_environment`'s `log_analytics_workspace_id` input. |
| `name` | Workspace name. |
| `workspace_id` | Customer ID (workspace ID), distinct from the resource ID. |
| `primary_shared_key` | Primary shared key, `sensitive = true`. Not currently consumed by any module and not exposed as an `environments/dev` output — kept for future use (e.g. external log forwarding). |

## Notes

Application Insights integration is explicitly out of scope until a future block (see
`docs/azure-container-apps-deploy.md` known limitations) — this module creates only the
Log Analytics Workspace, no alerts, dashboards, or diagnostic settings.

## Block 4.10 scope

Module implemented and wired behind `create_monitoring` (default `false`). Only
`terraform plan` was validated — see [`../../README.md`](../../README.md) for the plan
scenarios. `terraform apply` was deferred to Block 4.11.

## Block 4.11 scope

`terraform apply -var-file="terraform.container-apps-env.example.tfvars"` created the real
Log Analytics Workspace: `log-fittrack-ai-dev`, `eastus`, SKU `PerGB2018`, retention 30 days.
Verified with `az monitor log-analytics workspace show`. See "Block 4.11" in
[`../../README.md`](../../README.md) for the full command log, outputs, and rollback path.
