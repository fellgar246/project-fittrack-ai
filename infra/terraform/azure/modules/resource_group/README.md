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

## Why the Resource Group is the first real resource

An Azure Resource Group is the base logical container for every other resource in a
subscription — ACR, Postgres, Container Apps, Key Vault, and everything else in this
project's roadmap must live inside one. It has no dependencies of its own and carries
no runtime cost, which makes it the safest possible "first real resource" to validate
the module → environment wiring against before anything billable exists.

## Destroy

Setting `create_resource_group = false` and running `terraform apply` removes the
Resource Group (assuming it was previously created). **Deleting a Resource Group
deletes everything inside it.** Today that's nothing — this module creates only the
Resource Group itself — but once future modules (ACR, Postgres, Container Apps, ...)
are enabled and scoped inside it, destroying the Resource Group destroys them too.
Always confirm what a Resource Group contains (`az resource list --resource-group
<name>`) before destroying it in an environment with real resources.
