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

# Escenario 3 — Resource Group + ACR (1 recurso a crear: azurerm_container_registry)
terraform plan -var-file="terraform.acr.example.tfvars"
```

- **Bloque 4.6**: `terraform apply -var-file="terraform.resource-group.example.tfvars"` ya se
  ejecutó y creó el Resource Group real (`rg-fittrack-ai-dev`, `eastus`). Es el único recurso en
  state (`module.resource_group[0].azurerm_resource_group.this`); todos los demás módulos siguen
  detrás de sus flags `create_*` en `false`. Ver la sección "Block 4.6" en
  [`../../README.md`](../../README.md) para el detalle completo.
- **Bloque 4.7**: `modules/acr` es ahora un módulo real, detrás de `create_acr` (default `false`).
  `terraform.acr.example.tfvars` previsualiza Resource Group + ACR; con el Resource Group ya en
  state, el plan debe mostrar exactamente `Plan: 1 to add, 0 to change, 0 to destroy` y el único
  recurso nuevo debe ser `module.acr[0].azurerm_container_registry.this`. **No se ejecutó
  `terraform apply` en este bloque.** Ver la sección "Block 4.7" en
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
