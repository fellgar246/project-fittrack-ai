# Module: resource_group

Creates a single Azure resource group. The first real module in the FitTrack AI
Terraform codebase — every other module (ACR, Key Vault, Postgres, Container Apps,
etc.) will be scoped inside the resource group this module creates.

## Status

**Implemented.** Called from `environments/dev/main.tf`, gated behind
`var.create_resource_group` (default `false`), so it creates nothing until that
flag is explicitly set to `true` in a future block.

## Inputs

| Name | Type | Description | Required |
|---|---|---|---|
| `name` | `string` | Name of the resource group. | yes |
| `location` | `string` | Azure region. | yes |
| `tags` | `map(string)` | Tags applied to the resource group. | no (default `{}`) |

## Outputs

| Name | Description |
|---|---|
| `id` | Resource group ID. |
| `name` | Resource group name. |
| `location` | Resource group location. |

## Example usage

```hcl
module "resource_group" {
  source = "../../modules/resource_group"
  count  = var.create_resource_group ? 1 : 0

  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}
```

Downstream modules that need the resource group's name/location should be given
`module.resource_group[0].name` / `module.resource_group[0].location` as inputs
once they are wired in.
