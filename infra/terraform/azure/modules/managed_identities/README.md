# Module: managed_identities

**Status:** implemented (Block 4.12) — gated by `create_managed_identities` (default
`false`) in `environments/dev`. No `terraform apply` has been run for this module
yet; only `terraform plan` has been validated.

## Purpose

Provisions a user-assigned managed identity for the FitTrack AI API, and grants it
the `AcrPull` role scoped to the `acr` module's registry. This is the passwordless
alternative to ACR's admin user (`admin_enabled=false`) — the Container App
authenticates to the private registry using this identity instead of a static
username/password, matching the approach documented in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md#10-acr-pull-access-managed-identity).

Depends on `resource_group` (for `name`/`location`) and `acr` (for the role
assignment scope). Enabling `create_managed_identities` requires both
`create_resource_group=true` and `create_acr=true` (enforced by validations on
`create_managed_identities` in `environments/dev/variables.tf`).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | From `local.api_identity_name`. |
| `resource_group_name` | `string` | — | From `module.resource_group`. |
| `location` | `string` | — | From `module.resource_group`. |
| `acr_id` | `string` | — | From `module.acr` — scope for the `AcrPull` role assignment. |
| `tags` | `map(string)` | `{}` | Common tags. |

## Outputs

| Name | Description |
|---|---|
| `id` | Identity resource ID — consumed by `container_apps`'s `identity_id` input. |
| `name` | Identity name. |
| `principal_id` | Used internally for the `AcrPull` role assignment; not currently exposed by `environments/dev`. |
| `client_id` | Client ID of the identity — exposed as `api_identity_client_id` for future use (e.g. AAD-based auth). |
| `acr_pull_role_assignment_id` | Resource ID of the `AcrPull` role assignment, for traceability. |

## Notes

This module creates exactly two resources: `azurerm_user_assigned_identity` and
`azurerm_role_assignment` (role `AcrPull`, scoped to `var.acr_id`). No Key Vault
access policy, no other role assignments, and no identity for any component other
than the API are created here. `skip_service_principal_aad_check` is intentionally
not set — it exists to work around AAD propagation delays for identities created
moments earlier in the same apply, which isn't a concern for a plan-only block; it
can be added later if a real `apply` hits propagation timing issues.

## Block 4.12 scope

Module implemented and wired behind `create_managed_identities` (default `false`).
Only `terraform plan` was validated — see [`../../README.md`](../../README.md) for
the plan scenario. `terraform apply` is deferred to a future block.
