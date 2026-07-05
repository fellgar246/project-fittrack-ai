# Terraform modules — FitTrack AI (Azure)

One module per Azure service. Each module is small, reusable, parameterized by
inputs, explicit in outputs, and never hardcodes secrets. The `environments/dev`
layer is the only place that wires modules together and decides, via `create_*`
feature flags, which ones actually create resources.

## Status

| Module | Status | Target block |
|---|---|---|
| [`resource_group`](resource_group/README.md) | **Implemented** (gated by `create_resource_group`, default `false`) | 4.4 |
| [`acr`](acr/README.md) | Placeholder | 4.6 |
| [`managed_identities`](managed_identities/README.md) | Placeholder | 4.7 |
| [`key_vault`](key_vault/README.md) | Placeholder | 4.8 |
| [`networking`](networking/README.md) | Placeholder | 4.9 |
| [`postgres_flexible`](postgres_flexible/README.md) | Placeholder | 4.10 |
| [`monitoring`](monitoring/README.md) | Placeholder | 4.11 |
| [`container_apps_environment`](container_apps_environment/README.md) | Placeholder | 4.12 |
| [`container_apps`](container_apps/README.md) | Placeholder | 4.13 |

"Placeholder" means the folder currently contains only a `README.md` describing
the module's future purpose, inputs, and outputs — no `.tf` files, no resources.
Block numbers above are indicative planning, not a commitment; they may shift as
the project evolves.

## Planned module flow

```text
resource_group
  ├── acr
  ├── key_vault
  ├── managed_identities
  ├── networking
  ├── postgres_flexible
  ├── monitoring
  └── container_apps_environment
        └── container_apps
```

Every module below `resource_group` will take that module's `name`/`location`
outputs as inputs, so nothing is ever created outside the resource group.

## Cost control

Every module is opt-in via a `create_<module>` boolean flag declared in
`environments/dev/variables.tf`, defaulting to `false`. `terraform.tfvars.example`
ships with **all flags off**, so `terraform plan`/`apply` against the example file
creates zero billable resources. Enabling a flag and running `terraform apply` is
always an explicit, separate decision — never a side effect of adding a module.

## Apply policy

`terraform apply` is **not run** as part of building out this module structure.
Modules are added and wired with their flags off; a real `apply` only happens when
a future block explicitly authorizes it (starting with `create_resource_group=true`
in Block 4.5).
