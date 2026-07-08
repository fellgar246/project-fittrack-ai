# dev environment — quickstart

Guía completa: [`../../README.md`](../../README.md).

```bash
cd infra/terraform/azure/environments/dev

terraform fmt -recursive
terraform init
terraform validate

# Escenario 1 — todo apagado (0 recursos a crear/cambiar)
terraform plan -var-file="terraform.tfvars.example"

# Escenario 2 — sólo el Resource Group (0 recursos a crear: ya está en state desde el Bloque 4.6)
terraform plan -var-file="terraform.resource-group.example.tfvars"

# Escenario 3 — Resource Group + ACR (0 recursos a crear: ambos ya están en state desde el Bloque 4.8)
terraform plan -var-file="terraform.acr.example.tfvars"

# Escenario 4 — + Monitoring + Container Apps Environment (0 recursos a crear: ambos ya están en state desde el Bloque 4.11)
terraform plan -var-file="terraform.container-apps-env.example.tfvars"

# Escenario 5 — + Managed Identity + AcrPull + Container App (0 recursos a crear: los 3 ya están en state desde el Bloque 4.13)
terraform plan -var-file="terraform.container-app.example.tfvars"

# Escenario 6 — + Key Vault + Container App secret wiring (0 recursos a crear: todos ya están en state desde el Bloque 4.15)
terraform plan -var-file="terraform.key-vault.example.tfvars"

# Escenario 7 — + PostgreSQL Flexible Server (0 recursos a crear si ya aplicado en Bloque 4.17)
terraform plan -var-file="terraform.postgres.example.tfvars"
```

- **Bloque 4.6**: `terraform apply -var-file="terraform.resource-group.example.tfvars"` ya se
  ejecutó y creó el Resource Group real (`rg-fittrack-ai-dev`, `eastus`). Ver la sección
  "Block 4.6" en [`../../README.md`](../../README.md) para el detalle completo.
- **Bloque 4.7**: `modules/acr` se convirtió en módulo real, detrás de `create_acr` (default
  `false`). Sólo planificación — no se ejecutó `terraform apply` en este bloque. Ver la sección
  "Block 4.7" en [`../../README.md`](../../README.md).
- **Bloque 4.8**: `terraform apply -var-file="terraform.acr.example.tfvars"` ya se ejecutó y creó
  el Azure Container Registry real (`acrfittrackaidevdev01`). El state ahora contiene exactamente
  `module.resource_group[0].azurerm_resource_group.this` y
  `module.acr[0].azurerm_container_registry.this`; todos los demás módulos siguen detrás de sus
  flags `create_*` en `false`. Ver la sección "Block 4.8" en [`../../README.md`](../../README.md)
  para el detalle completo, incluyendo los comandos futuros de Docker login/tag/push.
- **Bloque 4.9**: se publicó la imagen productiva del backend en el ACR del Bloque 4.8:
  `acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9`. Sólo Docker build/tag/push y
  verificación con Azure CLI — el Terraform state no cambió (siguen siendo exactamente los mismos
  dos recursos). Ver la sección "Block 4.9" en [`../../README.md`](../../README.md) para el
  detalle completo, incluyendo la desviación del smoke test respecto al plan original.
- **Bloque 4.10**: `modules/monitoring` y `modules/container_apps_environment` se convirtieron en
  módulos reales, detrás de `create_monitoring` y `create_container_apps_environment` (ambos
  default `false`). Sólo planificación — no se ejecutó `terraform apply`. Ver la sección
  "Block 4.10" en [`../../README.md`](../../README.md) para el detalle completo, incluyendo por
  qué el Container Apps Environment usa el resource ID del workspace en vez de una shared key.
- **Bloque 4.11**: `terraform apply -var-file="terraform.container-apps-env.example.tfvars"` ya se
  ejecutó y creó el Log Analytics Workspace (`log-fittrack-ai-dev`) y el Azure Container Apps
  Environment (`cae-fittrack-ai-dev`) reales. El state ahora contiene 4 recursos: Resource Group,
  ACR, Log Analytics Workspace y Container Apps Environment; los demás módulos siguen detrás de
  sus flags `create_*` en `false`. El Escenario 4 de arriba ahora muestra `No changes`. Ver la
  sección "Block 4.11" en [`../../README.md`](../../README.md) para el detalle completo,
  incluyendo la verificación con Azure CLI y el rollback controlado.
- **Bloque 4.12**: `modules/managed_identities` y `modules/container_apps` se convirtieron en
  módulos reales, detrás de `create_managed_identities` y `create_container_apps` (ambos default
  `false`). Sólo planificación — no se ejecutó `terraform apply`. Ver la sección "Block 4.12" en
  [`../../README.md`](../../README.md) para el detalle completo, incluyendo por qué la Container
  App usa Managed Identity en vez de admin user y qué variables son placeholders de planificación.
- **Bloque 4.13**: `terraform apply -var-file="terraform.container-app.example.tfvars"` ya se
  ejecutó y creó la Managed Identity (`id-fittrack-ai-api-dev`), el role assignment `AcrPull` y la
  Container App real (`ca-fittrack-ai-api-dev`). El state ahora contiene 7 recursos (Resource
  Group, ACR, Log Analytics Workspace, Container Apps Environment, Managed Identity, role
  assignment `AcrPull` y Container App). El Escenario 5 de arriba ahora muestra `No changes`.

  Post-apply, el plan confirma:

  ```text
  Terraform has compared your real infrastructure against your configuration and found no
  differences, so no changes are needed.
  ```

  URL canónica del health check (FQDN limpio reportado por Azure CLI — la que se usa en
  README/portfolio):

  ```text
  https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health
  ```

  ```bash
  curl "https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health"
  ```

  ```json
  {"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
  ```

  ```bash
  az containerapp show \
    --name "ca-fittrack-ai-api-dev" \
    --resource-group "rg-fittrack-ai-dev" \
    --query "{name:name, provisioningState:properties.provisioningState, fqdn:properties.configuration.ingress.fqdn}" \
    -o json
  ```

  ```json
  {
    "fqdn": "ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io",
    "name": "ca-fittrack-ai-api-dev",
    "provisioningState": "Succeeded"
  }
  ```

  El output de Terraform (`api_container_app_url`) puede mostrar en cambio una URL de
  **revisión**, por ejemplo
  `https://ca-fittrack-ai-api-dev--j8xo7f2.wittydune-377fa2b0.eastus.azurecontainerapps.io` — para
  documentación pública siempre se usa el FQDN limpio de arriba, que es estable entre revisiones.

  Este es un deployment **demo/dev**: la Container App sigue usando placeholders para
  `DATABASE_URL`, `JWT_SECRET_KEY` y `AI_PROVIDER=fake` (aceptables solo para validar `/health`).
  Key Vault, secrets reales y Azure PostgreSQL siguen pendientes. Ver la sección "Block 4.13" en
  [`../../README.md`](../../README.md) para el detalle completo.
- **Bloque 4.14**: `modules/key_vault` se convirtió en módulo real con RBAC; `container_apps` ahora
  soporta Key Vault secret references. Se creó `terraform.key-vault.example.tfvars` para previsualizar
  Key Vault + wiring de secretos. **No se ejecutó `terraform apply`.** Con el Escenario 5
  (`terraform.container-app.example.tfvars`) el plan sigue mostrando `No changes`. Con el Escenario 6
  (`terraform.key-vault.example.tfvars`) el plan muestra Key Vault, role assignment, secretos demo y
  update in-place de la Container App. Ver la sección "Block 4.14" en
  [`../../README.md`](../../README.md) para el detalle completo.
- **Bloque 4.15**: `terraform apply -var-file="terraform.key-vault.example.tfvars"` ya se ejecutó
  y creó Key Vault (`kvfittrackaidevdev01`), el role assignment `Key Vault Secrets User`, los
  secretos demo (`JWT-SECRET-KEY`, `DATABASE-URL`) y actualizó la Container App para consumir
  secret references. El state ahora contiene 11 recursos. El Escenario 6 de arriba muestra
  `No changes` en infraestructura real. `/health` sigue respondiendo HTTP 200. Ver la sección
  "Block 4.15" en [`../../README.md`](../../README.md) para el detalle completo, incluyendo el
  prerrequisito de permisos `Key Vault Secrets Officer` para el Terraform runner y el rollback
  controlado.
- **Bloque 4.16**: `modules/postgres_flexible` se convirtió en módulo real, detrás de
  `create_postgres` (default `false`). Sólo planificación — no se ejecutó `terraform apply`.
  Ver la sección "Block 4.16" en [`../../README.md`](../../README.md).
- **Bloque 4.17**: `terraform apply -var-file="terraform.postgres.example.tfvars"` se ejecutó
  en dos fases: (1) crear PostgreSQL (`psql-fittrack-ai-pg-dev01`, `centralus`, DB
  `fittrack_ai`) y (2) actualizar secreto `DATABASE-URL` en Key Vault con wiring Terraform.
  El Escenario 7 de arriba muestra `No changes`. `/health` sigue HTTP 200. Alembic no se
  ejecutó. Ver la sección "Block 4.17" en [`../../README.md`](../../README.md).
- **Bloque 4.18**: Alembic ejecutado contra Azure PostgreSQL. Servidor manual
  `psql-test-centralus` eliminado. Regla firewall temporal `temp-local-alembic` (Azure CLI,
  IP local única) creada y removida. `DATABASE_URL` cargado desde Key Vault sin exponer
  valor. 9 tablas verificadas. API local validada contra DB cloud. Terraform plan final:
  `No changes`. `/health` cloud HTTP 200. Ver sección "Block 4.18" en
  [`../../README.md`](../../README.md).
- `terraform plan` requiere una sesión de Azure activa (`az login`) o `ARM_SUBSCRIPTION_ID`
  exportada — el provider `azurerm` construye un authorizer al configurarse aunque los flags
  `create_*` estén en `false` y no vaya a crear ningún recurso. `terraform validate` y
  `terraform fmt` sí funcionan sin credenciales.
- Desde el Bloque 4.4, `main.tf` llama a `modules/resource_group` en vez de declarar el recurso
  directamente. Ver [`../../modules/README.md`](../../modules/README.md) para la arquitectura
  completa de módulos.
- Desde el Bloque 4.5, `terraform.resource-group.example.tfvars` permite previsualizar la
  creación de únicamente el Resource Group sin tocar los defaults de
  `terraform.tfvars.example`. Los outputs `resource_group_enabled`, `resource_group_name`,
  `resource_group_id` y `resource_group_location` son seguros con el módulo desactivado
  (`terraform output` no falla; `id`/valores derivados caen a `null`/al nombre planeado).
- No commitear `terraform.tfvars` (usar `terraform.tfvars.example` como plantilla).
- Desde el Bloque 4.7, `terraform` requiere `>= 1.9.0` (antes `>= 1.6.0`), necesario para la
  validación cruzada `create_acr` → `create_resource_group` en `variables.tf`.
