# Module: networking (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.9.

## Purpose

Provision the virtual network and subnets needed to run the Container Apps
environment with private networking and to give the Container Apps environment
private connectivity to Azure Database for PostgreSQL Flexible Server (private
access, no public endpoint).

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `vnet_name` | `string` | Virtual network name. |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `location` | `string` | From `module.resource_group`. |
| `address_space` | `list(string)` | VNet CIDR range. |
| `subnet_configs` | `map(object)` | Subnet name/prefix pairs (e.g. `container-apps`, `postgres`). |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `vnet_id` | Virtual network ID. |
| `subnet_ids` | Map of subnet name → ID, consumed by `container_apps_environment` and `postgres_flexible`. |

## Notes

Enabled by `var.create_networking` (default `false`). Depends on `resource_group`.
Consumed by `container_apps_environment` (infrastructure subnet) and
`postgres_flexible` (delegated subnet for private access).
