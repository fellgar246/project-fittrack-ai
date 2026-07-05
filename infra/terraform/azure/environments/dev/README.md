# dev environment — quickstart

Guía completa: [`../../README.md`](../../README.md).

```bash
cd infra/terraform/azure/environments/dev

terraform fmt -recursive
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars.example"
```

- `terraform apply` está **fuera de alcance** en los Bloques 4.3 y 4.4.
- `terraform plan` requiere una sesión de Azure activa (`az login`) o `ARM_SUBSCRIPTION_ID`
  exportada — el provider `azurerm` construye un authorizer al configurarse aunque los 9 flags
  `create_*` estén en `false` y no vaya a crear ningún recurso. `terraform validate` y
  `terraform fmt` sí funcionan sin credenciales.
- Desde el Bloque 4.4, `main.tf` llama a `modules/resource_group` en vez de declarar el recurso
  directamente. Ver [`../../modules/README.md`](../../modules/README.md) para la arquitectura
  completa de módulos.
- No commitear `terraform.tfvars` (usar `terraform.tfvars.example` como plantilla).
