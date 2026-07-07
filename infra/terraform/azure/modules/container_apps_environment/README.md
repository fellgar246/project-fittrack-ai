# Module: container_apps_environment

**Status:** implemented and applied (Block 4.11) — gated by `create_container_apps_environment`
(default `false` in example tfvars, set to `true` in
`terraform.container-apps-env.example.tfvars`) in `environments/dev`. The real Azure Container
Apps Environment (`cae-fittrack-ai-dev`) exists in Azure.

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
for the plan scenarios. `terraform apply` was deferred to Block 4.11.

## Block 4.11 scope

`terraform apply -var-file="terraform.container-apps-env.example.tfvars"` created the real
Container Apps Environment: `cae-fittrack-ai-dev`, `eastus`, `provisioningState=Succeeded`,
`default_domain=wittydune-377fa2b0.eastus.azurecontainerapps.io`. Verified with
`az containerapp env show`. See "Block 4.11" in [`../../README.md`](../../README.md) for the
full command log, outputs, and rollback path. Managed Identity and `AcrPull` role assignment
are still not configured; they arrive when the real Container App is created in Block 4.12.
