# Module: container_apps_environment

**Status:** implemented (Block 4.10) — gated by `create_container_apps_environment`
(default `false`) in `environments/dev`. No `terraform apply` has been run for this
module yet; only `terraform plan` has been validated.

## Purpose

Provisions the Azure Container Apps Environment — the shared runtime that will host the
FitTrack AI API Container App — replacing the manual `az containerapp env create` step in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md#7-create-the-container-apps-environment).

Depends on `resource_group` (for `name`/`location`) and `monitoring` (for
`log_analytics_workspace_id`). Enabling `create_container_apps_environment` requires both
`create_resource_group=true` and `create_monitoring=true` (enforced by validations on
`create_container_apps_environment` in `environments/dev/variables.tf`).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | From `local.container_app_env_name`. |
| `resource_group_name` | `string` | — | From `module.resource_group`. |
| `location` | `string` | — | From `module.resource_group`. |
| `log_analytics_workspace_id` | `string` | — | Resource ID from `module.monitoring` (**not** the customer/workspace ID and **not** paired with a shared key — `azurerm_container_app_environment` only needs the workspace's resource ID). |
| `tags` | `map(string)` | `{}` | Common tags. |

## Outputs

| Name | Description |
|---|---|
| `id` | Environment resource ID, to be consumed by `container_apps` in a future block. |
| `name` | Environment name. |
| `default_domain` | Base domain for future Container App FQDNs. Known only after `apply`. |

## Notes

This module creates **only** `azurerm_container_app_environment`. Out of scope for this
module (and this block): the Container App itself, Container App Jobs, Managed
Identities, ingress, secrets, private networking/VNet integration, Dapr configuration,
custom domains, and certificates. The environment uses Azure's default public
networking; a dedicated/private VNet integration can be added later via the
`networking` module without needing to be designed upfront.

## Block 4.10 scope

Module implemented and wired behind `create_container_apps_environment` (default
`false`). Only `terraform plan` was validated — see [`../../README.md`](../../README.md)
for the plan scenarios. `terraform apply` is deferred to Block 4.11. Managed Identity and
`AcrPull` role assignment are not configured yet; they arrive when the real Container App
is created in a later block.
