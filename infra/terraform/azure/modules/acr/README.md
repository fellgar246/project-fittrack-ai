# Module: acr

**Status:** implemented and applied (Block 4.8) — gated by `create_acr` (default `false`) in
`environments/dev`. The real Azure Container Registry (`acrfittrackaidevdev01`) now exists.

## Purpose

Provisions the Azure Container Registry (ACR) that will store the FitTrack AI API
image, replacing the manual `az acr create` step documented in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md).

Depends on `resource_group`: it takes that module's `name`/`location` outputs as
inputs, so ACR is never created outside the resource group. Enabling `create_acr`
requires `create_resource_group=true` (enforced by a validation on `create_acr` in
`environments/dev/variables.tf`).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | ACR name (alphanumeric only, globally unique — see `local.acr_name`). |
| `resource_group_name` | `string` | — | From `module.resource_group`. |
| `location` | `string` | — | From `module.resource_group`. |
| `sku` | `string` | `"Basic"` | One of `Basic`, `Standard`, `Premium`. `Basic` is enough for dev/portfolio and keeps cost low. |
| `admin_enabled` | `bool` | `false` | Pull access is meant to go through a managed identity + `AcrPull` role assignment (added in a later block), not admin credentials. |
| `tags` | `map(string)` | `{}` | Common tags. |

## Outputs

| Name | Description |
|---|---|
| `id` | ACR resource ID (used for future `AcrPull` role assignments). |
| `login_server` | e.g. `acrfittrackaidevdev01.azurecr.io`. |
| `name` | ACR name. |

## Naming

ACR names are globally unique across Azure, alphanumeric only (no hyphens/uppercase),
and 5–50 characters. `environments/dev/locals.tf` derives `acr_name` from
`normalized_project_name` + `environment` + the optional `unique_suffix` variable, then
truncates to 50 characters. `unique_suffix` defaults to `""`; set it (3–8 lowercase
alphanumeric characters) if the base name collides with an existing registry.

## Block 4.7 scope

This block only implemented and planned the module — it did not run `terraform apply`.
See [`../../README.md`](../../README.md) for the plan scenarios and
[`environments/dev/README.md`](../../environments/dev/README.md) for the exact commands.

## Block 4.8 scope

`terraform apply -var-file="terraform.acr.example.tfvars"` ran successfully, creating exactly
`module.acr[0].azurerm_container_registry.this` (`acrfittrackaidevdev01`, SKU `Basic`,
`admin_enabled=false`). Verified via `terraform state list`, `terraform output`, and
`az acr show`. No Docker image has been pushed to this registry yet — that is planned for
Block 4.9. `AcrPull` role assignment is not configured yet; it requires a Managed Identity
that does not exist yet. See the "Block 4.8" section in
[`../../README.md`](../../README.md) for the full apply output and verification commands.
