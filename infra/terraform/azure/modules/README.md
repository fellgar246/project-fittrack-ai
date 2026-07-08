# Terraform modules — FitTrack AI (Azure)

One module per Azure service. Each module is small, reusable, parameterized by
inputs, explicit in outputs, and never hardcodes secrets. The `environments/dev`
layer is the only place that wires modules together and decides, via `create_*`
feature flags, which ones actually create resources.

## Status

| Module | Status | Target block |
|---|---|---|
| [`resource_group`](resource_group/README.md) | **Implemented and applied** (gated by `create_resource_group`, default `false`) | 4.4 / apply 4.6 |
| [`acr`](acr/README.md) | **Implemented and applied** (gated by `create_acr`, default `false`) | 4.7 / apply 4.8 |
| [`managed_identities`](managed_identities/README.md) | **Implemented and applied** (gated by `create_managed_identities`, default `false`) | 4.12 / apply 4.13 |
| [`key_vault`](key_vault/README.md) | **Implemented and applied** (gated by `create_key_vault`, default `false`) | 4.14 / apply 4.15 |
| [`networking`](networking/README.md) | Placeholder | 4.9 |
| [`postgres_flexible`](postgres_flexible/README.md) | Placeholder | 4.10 |
| [`monitoring`](monitoring/README.md) | **Implemented and applied** (gated by `create_monitoring`, default `false`) | 4.10 / apply 4.11 |
| [`container_apps_environment`](container_apps_environment/README.md) | **Implemented and applied** (gated by `create_container_apps_environment`, default `false`) | 4.10 / apply 4.11 |
| [`container_apps`](container_apps/README.md) | **Implemented and applied** (gated by `create_container_apps`, default `false`) | 4.12 / apply 4.13 / KV secrets 4.15 |

"Placeholder" means the folder currently contains only a `README.md` describing
the module's future purpose, inputs, and outputs — no `.tf` files, no resources.
"Implemented" means real `.tf` files exist and the module creates resources when
its `create_*` flag is enabled, regardless of whether `terraform apply` has been
run yet. Block numbers above are indicative planning, not a commitment; they may
shift as the project evolves.

`managed_identities` and `container_apps` were applied in Block 4.13. Key Vault and secret wiring
were applied in Block 4.15.

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
a future block explicitly authorizes it. `create_resource_group=true` was authorized
in Block 4.5/4.6; every other flag, including `create_acr`, stays `false` by default.
