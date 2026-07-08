# Module: managed_identities

**Status:** implemented and applied in Block 4.13 — gated by
`create_managed_identities` (default `false`, set to `true` in
`terraform.container-app.example.tfvars`) in `environments/dev`. `terraform apply`
has been run and both resources exist in Azure.

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
not set on the role assignment. The real Block 4.13 apply did hit AAD propagation
timing: pulling the image right after the role assignment was created failed with
`ContainerAppOperationError: unable to pull image using Managed identity`. Rather
than setting `skip_service_principal_aad_check` here, `environments/dev/main.tf`
adds a `time_sleep` resource (60s) between this module and `container_apps`,
keeping the propagation workaround at the environment level instead of baking it
into the module.

## Status

Implemented and applied in Block 4.13.

This module creates:

- User Assigned Managed Identity for the API
- AcrPull role assignment over the private Azure Container Registry

This allows Azure Container Apps to pull the backend image from ACR without using
static credentials.

## Security decision

ACR admin user remains disabled.

The API Container App authenticates to ACR using Managed Identity + RBAC instead
of username/password credentials.

This validates a cloud-native authentication pattern suitable for portfolio and
interview discussion.
