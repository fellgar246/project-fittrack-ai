# Module: postgres_flexible (placeholder)

**Status:** placeholder — no `.tf` files yet. Target block: 4.10.

## Purpose

Provision Azure Database for PostgreSQL Flexible Server plus the `fittrack_ai`
database, replacing local Docker Compose Postgres for the deployed API. The
connection string this module produces becomes the real `DATABASE_URL` secret
(replacing the placeholder used in
[`docs/azure-container-apps-deploy.md`](../../../../docs/azure-container-apps-deploy.md)).

## Planned inputs

| Name | Type | Description |
|---|---|---|
| `server_name` | `string` | From `local.postgres_server_name`. |
| `database_name` | `string` | From `local.postgres_database_name` (`fittrack_ai`). |
| `resource_group_name` | `string` | From `module.resource_group`. |
| `location` | `string` | From `module.resource_group`. |
| `subnet_id` | `string` | Delegated subnet, from `networking`, for private access. |
| `sku_name` | `string` | e.g. `"B_Standard_B1ms"` (burstable, low-cost tier for a portfolio project). |
| `administrator_login` | `string` | Admin username (value from a variable, never hardcoded). |
| `administrator_password` | `string` | Sensitive; sourced from a variable or Key Vault, never committed. |
| `tags` | `map(string)` | Common tags. |

## Planned outputs

| Name | Description |
|---|---|
| `fqdn` | Server hostname, used to build `DATABASE_URL`. |
| `database_name` | Database name. |

## Notes

Enabled by `var.create_postgres` (default `false`). Depends on `resource_group`
and `networking`. Alembic migrations against this server are run as a separate,
explicit step (never automatically on Container App startup — see
[`docs/azure-container-apps-deploy.md` §12](../../../../docs/azure-container-apps-deploy.md#12-migrations)).
