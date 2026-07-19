# FitTrack AI — Azure Terraform

## Executive summary (Block 5.11)

> **Mobile + Cloud checkpoint:** [docs/mobile-cloud-release-checkpoint.md](../../../docs/mobile-cloud-release-checkpoint.md)

| Item | Value |
|------|-------|
| Environment | `environments/dev/` |
| Backend image tag | `block-5.8-amd64-fix` |
| Terraform plan | Clean (No changes when aligned) |
| Key modules | resource_group, acr, monitoring, container_apps_environment, managed_identities, container_apps, key_vault, postgres, blob_storage, azure_openai |

### Safe plan (dev)

```bash
cd infra/terraform/azure
terraform fmt -check -recursive

cd environments/dev
terraform init -backend=false
terraform validate
terraform plan \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars" \
  -var-file="terraform.blob-storage.example.tfvars"
```

### CI quality gate (Block 6.2)

Pull requests touching `infra/terraform/**` run the **Terraform quality** check via
[`.github/workflows/terraform-ci.yml`](../../../.github/workflows/terraform-ci.yml):

- `terraform fmt -check -recursive` (from `infra/terraform/azure/`)
- `terraform init -backend=false` + `terraform validate` (in `environments/dev/`)
- Trivy config scan (CRITICAL/HIGH blocking)
- Gitleaks secret scan
- Prohibited file hygiene check (no tracked state, local tfvars, or plan files)

Cloud-backed `terraform plan` with OIDC is enabled in Block 6.3 when `TERRAFORM_CLOUD_PLAN_ENABLED=true`.
Protected backend deployment: [docs/azure-oidc-protected-deployment.md](../../../docs/azure-oidc-protected-deployment.md).
Bootstrap: [bootstrap/github-oidc/README.md](bootstrap/github-oidc/README.md).
Full documentation: [docs/terraform-ci-security.md](../../../docs/terraform-ci-security.md).

- `terraform.azure-openai.local.tfvars` is **local and gitignored** — never commit it.
- **Never apply using only example tfvars** when local Azure OpenAI values are required.
- Review every plan manually; do not use `-auto-approve` without review.
- **Do not run `terraform destroy`** unless formally closing the demo environment.

### Deploy sequence (when code or image changes)

1. Backend tests + Alembic migration locally
2. `docker build --platform linux/amd64` → push to ACR
3. Update `container_app_image_tag` in local tfvars
4. `terraform plan` → review → `terraform apply`
5. Run cloud Alembic migration if schema changed
6. `GET /health` → smoke scripts
7. Final drift check (`terraform plan` → No changes)

See [azure-blob-progress-photos.md](../../../docs/azure-blob-progress-photos.md) for Blob Storage RBAC details.

---

## 1. Objetivo

Este documento cubre cuatro bloques:

- **Bloque 4.3 — Terraform Foundation for Azure**: creó la base (provider, variables, naming,
  tags, un único recurso opcional) sin desplegar nada real. Reemplazó el deploy manual vía `az`
  CLI (`docs/azure-container-apps-deploy.md`) por infraestructura declarada, versionada y
  reproducible.
- **Bloque 4.4 — Terraform Modular Architecture Alignment**: reorganiza esa foundation en una
  arquitectura **environment + modules**: `environments/dev` sigue siendo el plano maestro, pero
  cada servicio de Azure vive (o vivirá) en su propio módulo bajo `modules/`. El primer módulo
  real es `resource_group` (ver [`modules/resource_group/README.md`](modules/resource_group/README.md));
  los otros ocho son placeholders documentados.
- **Bloque 4.5 — Terraform Resource Group Activation Plan**: prepara la activación controlada del
  primer recurso real (sin ejecutar `terraform apply`). Agrega
  `terraform.resource-group.example.tfvars` para previsualizar con `terraform plan` la creación de
  exactamente 1 recurso (`azurerm_resource_group`), y outputs seguros (`resource_group_enabled`,
  `resource_group_name`, `resource_group_id`, `resource_group_location`) que no fallan cuando el
  módulo está desactivado.
- **Bloque 4.6 — First Terraform Apply: Resource Group Only**: ejecuta el primer `terraform apply`
  real del proyecto, autorizado y controlado, creando únicamente el Azure Resource Group
  (`rg-fittrack-ai-dev`). Ver la sección [Block 4.6](#block-46--first-resource-group-apply) más
  abajo para el detalle completo (comandos, outputs, verificación).
- **Bloque 4.7 — Terraform ACR Module Plan**: convierte `modules/acr` de placeholder a módulo real
  y lo conecta en `environments/dev` detrás de `create_acr` (default `false`). Solo planificación —
  no ejecuta `terraform apply`. Ver la sección [Block 4.7](#block-47--terraform-acr-module-plan)
  más abajo.
- **Bloque 4.8 — Terraform ACR Apply & Docker Push Preparation**: ejecuta el `terraform apply`
  autorizado que crea el Azure Container Registry real (`acrfittrackaidevdev01`), verifica el
  resultado con Azure CLI, y documenta (sin ejecutar) los comandos futuros de `az acr login` /
  `docker build` / `docker tag` / `docker push`. Ver la sección
  [Block 4.8](#block-48--acr-apply) más abajo.
- **Bloque 4.9 — Docker Build, Tag & Push to ACR**: publica la imagen productiva del backend
  (`fittrack-api:block-4.9`) en el ACR del Bloque 4.8. Sin cambios de Terraform. Ver la sección
  [Block 4.9](#block-49--docker-build-tag--push-to-acr) más abajo.
- **Bloque 4.10 — Terraform Container Apps Environment Module Plan**: convierte
  `modules/monitoring` y `modules/container_apps_environment` de placeholder a módulos reales
  (Log Analytics Workspace + Container Apps Environment) y los conecta en `environments/dev`
  detrás de `create_monitoring` y `create_container_apps_environment` (ambos default `false`).
  Solo planificación — no ejecuta `terraform apply`. Ver la sección
  [Block 4.10](#block-410--terraform-container-apps-environment-module-plan) más abajo.
- **Bloque 4.11 — Terraform Container Apps Environment Apply**: ejecuta el `terraform apply`
  autorizado que crea el Log Analytics Workspace (`log-fittrack-ai-dev`) y el Azure Container
  Apps Environment (`cae-fittrack-ai-dev`) reales, verifica el resultado con Azure CLI, y confirma
  outputs como `default_domain`. Ver la sección
  [Block 4.11](#block-411--container-apps-environment-apply) más abajo.
- **Bloque 4.12 — Terraform Container App Module Plan**: convierte `modules/managed_identities`
  y `modules/container_apps` de placeholder a módulos reales (User Assigned Managed Identity +
  rol `AcrPull` + Container App de la API) y los conecta en `environments/dev` detrás de
  `create_managed_identities` y `create_container_apps` (ambos default `false`). Solo
  planificación — no ejecuta `terraform apply`. Ver la sección
  [Block 4.12](#block-412--container-app-module-plan) más abajo.
- **Bloque 4.13 — Container App Apply: API Health Check Demo**: ejecuta el `terraform apply`
  autorizado que crea la Managed Identity, el role assignment `AcrPull` y la Container App reales
  (`ca-fittrack-ai-api-dev`), dejando `GET /health` públicamente accesible. Ver la sección
  [Block 4.13](#block-413--container-app-apply-api-health-check-demo) más abajo.
- **Bloque 4.14 — Key Vault + Container App Secrets Plan**: implementa el módulo `key_vault` con
  RBAC, extiende `container_apps` para secret references desde Key Vault, y valida el plan con
  `terraform.key-vault.example.tfvars` — **sin `terraform apply`**. Ver la sección
  [Block 4.14](#block-414--key-vault--container-app-secrets-plan) más abajo.
- **Bloque 4.15 — Key Vault Apply + Container App Secret Wiring**: ejecuta el `terraform apply`
  autorizado que crea Key Vault, secretos demo y actualiza la Container App a secret references.
  Ver la sección [Block 4.15](#block-415--key-vault-apply--container-app-secret-wiring) más abajo.

**Los bloques 4.3, 4.4, 4.5, 4.7, 4.10, 4.12 y 4.14 no crean ningún recurso de Azure ni ejecutan
`terraform apply`.** Con todas las banderas `create_*` en `false` (default de
`terraform.tfvars.example`), `terraform plan` no agrega ni cambia ningún recurso — solo calcula
los outputs informativos. Los bloques 4.6, 4.8, 4.11, 4.13 y 4.15 son, hasta ahora, los únicos que han
ejecutado un `apply` real: el 4.6 creó el Resource Group, el 4.8 el Azure Container Registry, el
4.11 el Log Analytics Workspace y el Container Apps Environment, el 4.13 la Managed Identity,
el role assignment `AcrPull` y la Container App de la API, y el 4.15 Key Vault, secretos demo y
el wiring de secret references en la Container App.

## 2. Estructura creada

```
infra/terraform/azure/
├── .gitignore                    # ignora state/tfvars, NO ignora el lock file
├── README.md                     # este archivo
├── environments/
│   └── dev/
│       ├── versions.tf           # versión de Terraform + provider azurerm
│       ├── providers.tf          # configuración del provider azurerm
│       ├── variables.tf          # variables de entrada + 9 flags create_*
│       ├── locals.tf             # naming convention + tags comunes
│       ├── main.tf               # módulo resource_group (deshabilitado por default)
│       ├── outputs.tf            # nombres planeados, tags y planned_modules
│       ├── terraform.tfvars.example
│       ├── terraform.resource-group.example.tfvars  # previsualiza sólo el Resource Group
│       ├── terraform.acr.example.tfvars              # previsualiza Resource Group + ACR
│       ├── terraform.container-apps-env.example.tfvars  # + Monitoring + Container Apps Env
│       ├── terraform.container-app.example.tfvars       # + Managed Identity + Container App
│       ├── terraform.key-vault.example.tfvars           # + Key Vault + Container App secret wiring
│       └── README.md             # quickstart del entorno dev
└── modules/
    ├── README.md                 # overview de la capa de módulos
    ├── resource_group/           # módulo real (main/variables/outputs.tf)
    ├── acr/                      # módulo real (main/variables/outputs.tf)
    ├── key_vault/                # módulo real (main/variables/outputs.tf)
    ├── managed_identities/       # módulo real (main/variables/outputs.tf)
    ├── networking/                # placeholder
    ├── postgres_flexible/        # módulo real (main/variables/outputs.tf)
    ├── container_apps_environment/  # módulo real (main/variables/outputs.tf)
    ├── container_apps/           # módulo real (main/variables/outputs.tf)
    └── monitoring/                # módulo real (main/variables/outputs.tf)
```

Ver [`modules/README.md`](modules/README.md) para el detalle de cada módulo, su estado
(implementado vs placeholder) y el bloque objetivo donde se implementará.

## 3. Por qué Terraform antes de crear más recursos manuales

`az` CLI es rápido para prototipar, pero no es reproducible ni auditable: no hay un registro
declarativo de qué existe, y recrear el entorno desde cero implica repetir comandos a mano.
Terraform da:

- Un **plan** antes de aplicar cualquier cambio (visibilidad previa).
- Un **estado** que refleja la infraestructura real.
- **Reproducibilidad**: el mismo código crea el mismo entorno en cualquier máquina.
- Una base limpia para los bloques futuros (ACR, Container Apps, PostgreSQL) sin deuda técnica.

## 4. Provider y versiones

```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

`required_version` subió de `>= 1.6.0` a `>= 1.9.0` en el Bloque 4.7: la validación cruzada de
`create_acr` (que exige `create_resource_group=true`) usa una referencia entre variables dentro de
un bloque `validation`, soportada desde Terraform 1.9.

Se usa `azurerm ~> 4.0` (línea estable actual del provider). **Detalle importante:** a partir de
la v4, `azurerm` **requiere `subscription_id`** en el bloque `provider`. Para no hardcodear ese
valor, `providers.tf` lo toma de `var.subscription_id` (default `null`), y Terraform hace
fallback automático a la variable de entorno `ARM_SUBSCRIPTION_ID` o al contexto activo de
`az login` cuando no se define explícitamente:

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

## 5. Variables

| Variable | Tipo | Default | Descripción |
|---|---|---|---|
| `project_name` | string | `"fittrack-ai"` | Nombre del proyecto, usado en el naming. |
| `environment` | string | `"dev"` | `dev`, `staging` o `prod` (validado). |
| `location` | string | `"eastus"` | Región de Azure. |
| `owner` | string | *(requerido)* | Dueño/mantenedor de los recursos. |
| `cost_center` | string | `"portfolio"` | Etiqueta de costos. |
| `subscription_id` | string | `null` | Preferir `ARM_SUBSCRIPTION_ID` o `az login`; no commitear valores reales. |
| `create_resource_group` | bool | `false` | Habilita `module.resource_group`. |
| `create_acr` | bool | `false` | Habilita `module.acr`. Requiere `create_resource_group=true` (validado). |
| `acr_sku` | string | `"Basic"` | `Basic`, `Standard` o `Premium`. |
| `acr_admin_enabled` | bool | `false` | Debe permanecer `false`; el acceso futuro es vía managed identity. |
| `unique_suffix` | string | `""` | Sufijo opcional (3–8 alfanumérico minúscula) para nombres globales como ACR. |
| `create_key_vault` | bool | `false` | Habilita `module.key_vault`. Requiere `create_resource_group=true` y `create_managed_identities=true` (validado). |
| `key_vault_sku_name` | string | `"standard"` | `standard` o `premium`. |
| `key_vault_soft_delete_retention_days` | number | `7` | Entre 7 y 90 días. |
| `key_vault_purge_protection_enabled` | bool | `false` | Protección contra purge del vault. |
| `api_jwt_secret_key` | string | *(demo placeholder)* | JWT secret (sensitive). Solo en tfvars locales o placeholders demo. |
| `api_database_url` | string | *(demo placeholder)* | Database URL (sensitive). Placeholder hasta PostgreSQL real. |
| `create_managed_identities` | bool | `false` | Habilita `module.managed_identities`. Requiere `create_resource_group=true` y `create_acr=true` (validado). |
| `create_networking` | bool | `false` | Planeado — `modules/networking` es placeholder. |
| `create_postgres` | bool | `false` | Habilita `module.postgres_flexible`. Requiere `create_resource_group=true` y `create_key_vault=true` (validado). |
| `postgres_location` | string | `null` | Región para PostgreSQL; override cuando la suscripción restringe la región principal (ej. `centralus`). |
| `postgres_administrator_login` | string | `"fittrackadmin"` | Usuario admin de PostgreSQL. |
| `postgres_version` | string | `"16"` | Versión de PostgreSQL. |
| `postgres_sku_name` | string | `"B_Standard_B1ms"` | SKU burstable para dev/portfolio. |
| `postgres_storage_mb` | number | `32768` | Almacenamiento en MB (32 GB). |
| `postgres_backup_retention_days` | number | `7` | Retención de backup (7–35 días). |
| `postgres_public_network_access_enabled` | bool | `true` | Acceso público temporal para dev/demo. |
| `postgres_allowed_firewall_rules` | map | `{}` | Reglas de firewall; vacío por default. |
| `create_container_apps_environment` | bool | `false` | Habilita `module.container_apps_environment`. Requiere `create_resource_group=true` y `create_monitoring=true` (validado). |
| `create_container_apps` | bool | `false` | Habilita `module.container_apps`. Requiere `create_resource_group=true`, `create_acr=true`, `create_container_apps_environment=true` y `create_managed_identities=true` (validado). |
| `create_monitoring` | bool | `false` | Habilita `module.monitoring`. Requiere `create_resource_group=true` (validado). |
| `log_analytics_sku` | string | `"PerGB2018"` | `Free` o `PerGB2018`. |
| `log_analytics_retention_in_days` | number | `30` | Entre 30 y 730 días. |
| `api_image_tag` | string | `"block-4.23-amd64"` | Tag de la imagen del backend publicada en ACR. `block-4.23-amd64` es la imagen cloud actual con fix Azure OpenAI; `block-4.13-amd64` fue el primer rebuild `linux/amd64`; `block-4.9` era `linux/arm64` y Azure Container Apps lo rechaza. |
| `api_cpu` | number | `0.25` | CPU asignada a la Container App de la API. |
| `api_memory` | string | `"0.5Gi"` | Memoria asignada a la Container App de la API. |
| `api_min_replicas` | number | `0` | Mínimo de réplicas (permite scale-to-zero). |
| `api_max_replicas` | number | `1` | Máximo de réplicas. |
| `api_target_port` | number | `8000` | Puerto expuesto por el contenedor FastAPI. |

## 5.1. Modules layer

`environments/dev` es el **plano maestro**: define providers, variables, locals, outputs y
banderas, y conecta módulos pasando outputs de uno como inputs de otro. Cada módulo bajo
`modules/` se enfoca en **un solo servicio de Azure**, es reutilizable, parametrizado por
inputs explícitos, expone outputs claros, y nunca hardcodea secretos.

Flujo de módulos planeado (cada uno depende del anterior donde aplica):

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

Ver [`modules/README.md`](modules/README.md) para la tabla de estado (implementado vs
placeholder) de cada módulo.

## 5.2. Cost control

Cada módulo se activa con su propia bandera `create_<módulo>` (todas en `false` por default en
`terraform.tfvars.example`). Esto permite:

- Desplegar por partes: habilitar un módulo a la vez y correr `apply` solo sobre ese cambio.
- Mantener costo cero mientras se itera en la arquitectura Terraform.
- Destruir de forma limpia: apagar una bandera y `apply` elimina solo ese recurso.

## 5.3. Apply policy

`terraform apply` **no se ejecuta** como parte de construir o extender esta estructura. Un
`apply` real solo ocurre cuando un bloque futuro lo autoriza explícitamente. El Bloque 4.6
habilitó `create_resource_group = true`, el Bloque 4.8 `create_acr = true`, el Bloque 4.11
`create_monitoring = true` y `create_container_apps_environment = true`, y el Bloque 4.13
`create_managed_identities = true` y `create_container_apps = true`. Las 3 banderas restantes
(`create_key_vault`, `create_networking`, `create_postgres`) siguen en `false`; cada una se
activará en su propio bloque futuro.

## 6. Naming conventions

Todos los nombres se derivan en `locals.tf` a partir de `project_name` y `environment`, y ya
están validados contra las reglas de Azure para los recursos que vendrán en bloques futuros:

| Local | Valor (dev) | Regla de Azure |
|---|---|---|
| `resource_group_name` | `rg-fittrack-ai-dev` | ≤90 car., alfanumérico + `-._()` |
| `acr_name` | `acrfittrackaidev` (o con sufijo: `acrfittrackaidevdev01`) | 5–50 car., solo alfanumérico minúsculas, único global |
| `storage_account_name` | `stfittrackaidev` | 3–24 car., solo alfanumérico minúsculas, único global |
| `container_app_env_name` | `cae-fittrack-ai-dev` | ≤32 car., alfanumérico + `-` |
| `container_app_api_name` | `ca-fittrack-ai-api-dev` | ≤32 car., alfanumérico + `-` |
| `postgres_server_name` | `psql-fittrack-ai-dev` | 3–63 car., minúsculas/números/`-`, único global |
| `postgres_database_name` | `fittrack_ai` | permite `_` |
| `log_analytics_workspace` | `log-fittrack-ai-dev` | 4–63 car., alfanumérico + `-` |

ACR y Storage Account no admiten guiones ni mayúsculas, por eso usan
`normalized_project_name` (project_name en minúsculas y sin `-`).

## 7. Tags

Todos los recursos futuros deben recibir `local.common_tags`:

```hcl
common_tags = {
  project     = var.project_name
  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  managed_by  = "terraform"
}
```

## 8. Remote state (Block 6.3)

Terraform state is stored remotely in Azure Blob Storage:

| Setting | Value |
|---------|-------|
| Storage account | `stfittrackaidevtf01` |
| Container | `tfstate` |
| State key | `fittrack-ai-dev.tfstate` |
| Auth | Azure AD (`use_azuread_auth = true`) |

Bootstrap and migration: [bootstrap/github-oidc/README.md](bootstrap/github-oidc/README.md).

## 9. State local (historical — pre Block 6.3)

El estado se guardaba localmente (`terraform.tfstate`, ignorado por git). Block 6.3 migró el state al backend remoto anterior.

## 10. Por qué no remote state antes de Block 6.3 (historical)

Remote state requería un storage account dedicado y bootstrap OIDC — implementado en Block 6.3.

## 11. Por qué no crear recursos costosos todavía

Los bloques 4.3 y 4.4 son exclusivamente *foundation* y *estructura*: provider, variables,
naming, tags, outputs, módulos y documentación. El único recurso declarado en todo el árbol
(`module.resource_group`, dentro de `modules/resource_group/main.tf`) está detrás de
`create_resource_group = false` por default, y las otras 8 banderas `create_*` (una por módulo
placeholder) también están en `false`. `terraform plan`/`apply` con los valores de ejemplo no
crean ni cambian ningún recurso. El primer recurso real llega en el Bloque 4.5, habilitando
`create_resource_group = true`.

## 11. Cómo correr `terraform fmt`

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive
```

Formatea todos los `.tf` del entorno según el estilo canónico de Terraform.

## 12. Cómo correr `terraform init`

```bash
terraform init
```

Descarga el provider `azurerm ~> 4.0` y genera/actualiza `.terraform.lock.hcl` (se commitea, ver
sección 15).

## 13. Cómo correr `terraform validate`

```bash
terraform validate
```

Valida la sintaxis y coherencia interna del código. **No requiere credenciales de Azure.**

## 14. Cómo correr `terraform plan`

```bash
# Escenario 1 — todo apagado
terraform plan -var-file="terraform.tfvars.example"

# Escenario 2 — sólo el Resource Group (Bloque 4.5)
terraform plan -var-file="terraform.resource-group.example.tfvars"
```

Con `create_resource_group = false` (default, Escenario 1), el plan debe mostrar **"No changes"**
siempre que haya una sesión de Azure activa (`az login`) o `ARM_SUBSCRIPTION_ID` exportada —
`azurerm` valida credenciales al inicializarse aunque no vaya a crear recursos. Si no hay
credenciales, el plan falla al configurar el provider; esto es **esperado** en este bloque (ver
troubleshooting).

Con `terraform.resource-group.example.tfvars` (Escenario 2), el plan debe mostrar exactamente
`Plan: 1 to add, 0 to change, 0 to destroy` y el único recurso planeado debe ser
`azurerm_resource_group.this` (ningún ACR, Postgres, Container Apps, Key Vault, identidades, VNet
ni Log Analytics). Desde el Bloque 4.6 este escenario ya fue aplicado (ver más abajo); si vuelves
a correr este `plan` después del apply, debe mostrar **"No changes"**.

### Revisar outputs

```bash
terraform output
```

Con el módulo desactivado, `resource_group_enabled = false`, `resource_group_id = null`, y
`resource_group_name`/`resource_group_location` caen a los valores planeados (`local.*` /
`var.location`) en vez de fallar. Con `create_resource_group = true` (Bloque 4.6), reflejan los
valores reales del recurso creado.

### Destruir el Resource Group

```bash
terraform destroy -var-file="terraform.resource-group.example.tfvars"
# o, tras editar el flag a false en el tfvars usado:
terraform apply -var-file="<tfvars-usado>"
```

**Borrar el Resource Group borra todos los recursos que existan dentro de él.** Hoy no contiene
nada más que sí mismo, pero en cuanto se activen módulos futuros (ACR, Postgres, Container Apps,
...) dentro de este Resource Group, destruirlo los destruye también. Revisar
`az resource list --resource-group <name>` antes de destruir en un entorno con recursos reales.
**No se ha ejecutado `terraform destroy`** — el Resource Group creado en el Bloque 4.6 sigue
activo.

## 15. Decisión: `.terraform.lock.hcl` se commitea

Dos opciones evaluadas:

- **Commitear** el lock file: fija los hashes exactos del provider descargado, garantizando que
  cualquier máquina o pipeline de CI instale exactamente la misma versión. Es la práctica
  recomendada por HashiCorp.
- **Ignorarlo**: reduce un archivo en el repo, pero sacrifica reproducibilidad — dos entornos
  podrían resolver versiones de provider ligeramente distintas dentro del rango `~> 4.0`.

**Decisión: se commitea.** Para un proyecto de portfolio que busca demostrar buenas prácticas,
la reproducibilidad pesa más que la simplicidad de tener un archivo menos. Por eso
`infra/terraform/azure/.gitignore` **no** incluye `.terraform.lock.hcl`.

## 16. Qué NO hacer todavía

- No ejecutar `terraform apply` para ningún módulo más allá de `resource_group` (Bloque 4.6),
  `acr` (Bloque 4.8), `monitoring` y `container_apps_environment` (Bloque 4.11), y
  `managed_identities` y `container_apps` (Bloque 4.13).
- No crear PostgreSQL, Blob Storage ni recursos de Azure OpenAI vía Terraform.
- No hacer push de nuevas imágenes Docker al ACR real (el tag `block-4.13-amd64`, publicado en
  el Bloque 4.9/4.13, ya es el desplegado).
- No configurar remote state.
- No crear Key Vault.
- No configurar GitHub Actions / CI-CD.
- No commitear `terraform.tfvars`, `*.tfstate` ni ningún secreto.
- No hardcodear `subscription_id` ni ninguna credencial en archivos `.tf` o `.tfvars`.
- No ejecutar `terraform destroy` sobre el Resource Group, ACR, Container Apps Environment,
  Managed Identity ni Container App salvo instrucción explícita.

## 17. Troubleshooting

1. **`terraform: command not found`** → instalar Terraform (`brew install terraform` en macOS)
   y verificar con `terraform version`.
2. **`az: command not found`** → instalar Azure CLI (`brew install azure-cli`) y verificar con
   `az version`.
3. **No hay sesión Azure activa** → `az login` antes de `terraform plan`.
4. **Suscripción equivocada** → `az account show` para ver la activa; `az account set
   --subscription "<subscription-id>"` para cambiarla, o exportar `ARM_SUBSCRIPTION_ID`.
5. **Provider download falla** (`terraform init`) → revisar conectividad de red/proxy; reintentar
   `terraform init -upgrade`.
6. **`terraform init` falla** → borrar `.terraform/` (nunca el lock file) y reintentar; verificar
   que la versión de Terraform instalada cumpla `>= 1.6.0`.
7. **`terraform validate` falla** → normalmente un error de sintaxis; correr `terraform fmt
   -recursive` primero y leer el mensaje de error, que indica archivo y línea.
8. **`terraform plan` pide credenciales** → es esperado si no hay `az login` activo ni
   `ARM_SUBSCRIPTION_ID` exportada; ejecutar `az login` y reintentar.
9. **Variables requeridas faltantes** (`owner`) → Terraform la pedirá interactivamente, o
   definirla en `terraform.tfvars` (no commiteado) o con `-var="owner=tu-nombre"`.
10. **`terraform.tfvars` se intentó commitear por error** → el `.gitignore` de este directorio ya
    lo bloquea; si igual aparece en `git status`, correr `git rm --cached terraform.tfvars`.
11. **`.terraform.lock.hcl` no coincide** entre máquinas → correr `terraform init -upgrade` para
    regenerarlo intencionalmente, o `terraform providers lock` para fijar plataformas adicionales.
12. **Nombres inválidos para recursos futuros** → revisar la tabla de la sección 6; los locals ya
    están dentro de los límites de cada servicio, pero si se cambia `project_name` hay que
    re-validar longitudes (especialmente ACR y Storage Account, límite 24-50 caracteres).

## Decisiones técnicas (resumen)

1. **Migrar de `az` CLI manual a Terraform**: reproducibilidad, plan previo, y una base común
   para todos los entornos futuros.
2. **Foundation antes de recursos**: evita construir sobre naming/tags inconsistentes que
   habría que corregir después con recursos ya vivos.
3. **State local al inicio**: no hay backend remoto disponible todavía (requeriría un recurso
   de Azure que aún no existe) y el proyecto es de un solo colaborador.
4. **Remote state después**: se implementa una vez exista el Resource Group (Bloque 4.4+).
5. **Naming conventions desde el inicio**: cambiar nombres de recursos ya creados es disruptivo
   (algunos, como Storage Account, no se pueden renombrar sin recrear).
6. **Tags desde el inicio**: permiten trazabilidad de costos y ownership sin trabajo retroactivo.
7. **Sin secretos en Terraform**: `subscription_id` es opcional y se resuelve vía entorno/`az
   login`; ninguna contraseña o API key vive en este bloque (Key Vault llega después).
8. **Sin `terraform apply` todavía**: el bloque es de preparación; aplicar implica ya crear
   infraestructura, que es el objetivo explícito del Bloque 4.4.
9. **Nombres de ACR/ACA/PostgreSQL preparados aunque no se creen**: permite validar las reglas
   de naming de Azure (longitud, caracteres permitidos) sin gastar dinero, y deja los bloques
   futuros listos para solo referenciar `local.*`.
10. **Estructura modular desde el Bloque 4.4**: `environments/dev` es el plano maestro y cada
    servicio de Azure vive en su propio módulo bajo `modules/`. `resource_group` ya es un módulo
    real; el Bloque 4.5 solo necesita habilitar `create_resource_group = true` para su primer
    `apply`. Los siguientes módulos (ACR, Key Vault, identidades, networking, Postgres,
    monitoring, Container Apps) se añaden uno a la vez, cada uno detrás de su propia bandera.
11. **Módulos placeholder documentados en vez de carpetas vacías**: cada módulo no implementado
    tiene un `README.md` con inputs/outputs planeados, para que implementarlo después sea
    completar un contrato ya definido, no diseñarlo desde cero.
12. **ACR después del Resource Group (Bloque 4.7)**: `create_acr=true` está validado para exigir
    `create_resource_group=true`, evitando un módulo huérfano sin dónde crearse.
13. **`admin_enabled=false` en ACR**: el acceso desde Container Apps usará Managed Identity +
    rol `AcrPull` en un bloque futuro, no credenciales de admin embebidas.
14. **`sku="Basic"` en ACR**: suficiente para un proyecto de portfolio en dev; reduce costo frente
    a `Standard`/`Premium`.
15. **`unique_suffix` explícito en vez de `random_string`**: el nombre de ACR es global; un sufijo
    configurable resuelve colisiones sin introducir nombres no deterministas entre `plan` y
    `apply`.
16. **`terraform apply` de ACR diferido al Bloque 4.8**: el Bloque 4.7 separó deliberadamente la
    implementación del módulo (y su validación vía `plan`) de la creación real del recurso; el
    Bloque 4.8 ejecutó ese `apply`.
17. **Push de imágenes Docker separado del `apply` de ACR (Bloque 4.9)**: crear el registro
    (infraestructura) y poblarlo con imágenes (artefactos) son pasos independientes y auditables
    por separado.
18. **Log Analytics antes que Container Apps Environment (Bloque 4.10)**: ACA requiere el
    workspace en su creación (`log_analytics_workspace_id`); por eso `create_container_apps_environment`
    exige `create_monitoring=true`, no sólo `create_resource_group=true`.
19. **`container_apps_environment` usa el resource ID del workspace, no shared key**: el recurso
    `azurerm_container_app_environment` no tiene ningún argumento de shared key — el provider
    gestiona la autenticación internamente. `modules/monitoring` sí expone `primary_shared_key`
    (sensible) para uso futuro, pero no se pasa a `container_apps_environment` ni se expone como
    output del entorno.
20. **`terraform apply` de Monitoring/Container Apps Environment diferido al Bloque 4.11**: mismo
    patrón que ACR (Bloques 4.7/4.8) — separar implementación validada por `plan` de la creación
    real de recursos.
21. **Apply de Monitoring/Container Apps Environment ejecutado en el Bloque 4.11**: el `apply` se
    limitó explícitamente a los 2 recursos ya validados por `plan` en el Bloque 4.10, sin abrir la
    puerta a Container App, Managed Identity, AcrPull, Key Vault ni PostgreSQL en el mismo cambio.
22. **Apply de Managed Identity + AcrPull + Container App ejecutado en el Bloque 4.13**: el
    `apply` se limitó a los 3 recursos ya validados por `plan` en el Bloque 4.12. La imagen
    desplegada usa el tag `block-4.13-amd64` en vez de `block-4.9`: el Bloque 4.9 había publicado
    accidentalmente una imagen `linux/arm64` (build en Apple Silicon sin `--platform`), que Azure
    Container Apps rechaza; el Bloque 4.13 reconstruyó y publicó una imagen `linux/amd64` bajo el
    nuevo tag. Se agregó además un `time_sleep` de 60s entre la creación de la Managed Identity y
    el `apply` de la Container App, para absorber la propagación eventual del role assignment
    `AcrPull` en Azure AD (un apply previo sin esta espera falló con
    `ContainerAppOperationError: unable to pull image using Managed identity`).

## Precheck de Azure CLI (sin crear recursos)

```bash
az login
az account show
# Si hay varias suscripciones:
az account set --subscription "<subscription-id>"

terraform version
az version
```

## Block 4.6 — First Resource Group Apply

Status: **completed**

Created resources:

- Azure Resource Group (`rg-fittrack-ai-dev`, `eastus`)

Terraform state:

```text
module.resource_group[0].azurerm_resource_group.this
```

No other Azure services were created. Las 8 banderas restantes (`create_acr`,
`create_key_vault`, `create_managed_identities`, `create_networking`, `create_postgres`,
`create_container_apps_environment`, `create_container_apps`, `create_monitoring`) siguen en
`false`.

### Comandos ejecutados

```bash
cd infra/terraform/azure/environments/dev
export ARM_SUBSCRIPTION_ID="<subscription-id-activa>"   # resuelto vía az login, no hardcodeado

terraform fmt -recursive -check
terraform init
terraform validate
terraform plan -var-file="terraform.resource-group.example.tfvars"
terraform apply -var-file="terraform.resource-group.example.tfvars"   # confirmado manualmente con "yes"
```

No se usó `-auto-approve`. No se creó ni commiteó ningún `terraform.tfvars` — se aplicó
directamente con `terraform.resource-group.example.tfvars` (ya trae `owner="felipe"` y los flags
correctos), confiando en el `subscription_id` resuelto por el contexto `az login` /
`ARM_SUBSCRIPTION_ID`.

### Resultado del plan

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Único recurso planeado: `module.resource_group[0].azurerm_resource_group.this`.

### Resultado del apply

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

### Outputs relevantes

```text
resource_group_enabled  = true
resource_group_name     = "rg-fittrack-ai-dev"
resource_group_id       = "/subscriptions/<subscription-id>/resourceGroups/rg-fittrack-ai-dev"
resource_group_location = "eastus"
```

### Verificación

- `terraform state list` → únicamente `module.resource_group[0].azurerm_resource_group.this`.
- `az group show --name "$(terraform output -raw resource_group_name)" -o table` → confirma
  `rg-fittrack-ai-dev` en `eastus`.
- `az group show --name "$(terraform output -raw resource_group_name)" --query tags -o json` →
  confirma los 5 tags de `common_tags` (`project`, `environment`, `owner`, `cost_center`,
  `managed_by`).
- Backend: `uv run ruff check .` limpio. `uv run pytest` no se pudo correr en esta máquina porque
  el Docker daemon local (Postgres de test en `localhost:5433`) no estaba activo — no relacionado
  con este cambio de Terraform.

### Nota sobre el apply interactivo

`terraform apply` requiere una confirmación manual (`yes`) por una terminal real con TTY. No
puede ejecutarse vía canales no interactivos (p. ej. `echo "yes" | terraform apply` o el prefijo
`!` de Claude Code), que fallan con `Error: error asking for approval: EOF`. El apply real de este
bloque se corrió directamente en una terminal.

## Destroy Resource Group

Para destruir el Resource Group creado en este bloque:

```bash
cd infra/terraform/azure/environments/dev
terraform destroy -var-file="terraform.resource-group.example.tfvars"
```

**Warning:** destruir el Resource Group borra todos los recursos que existan dentro de él. Hoy
sólo contiene el Resource Group mismo, pero en cuanto se activen módulos futuros (ACR, Postgres,
Container Apps, ...) dentro de él, destruirlo los destruye también.

`terraform destroy` **no se ha ejecutado** — el Resource Group sigue activo.

## Block 4.7 — Terraform ACR Module Plan

Status: **completed** (implementación y planificación; sin `apply`).

Qué es ACR y para qué sirve en FitTrack AI: Azure Container Registry es el registro privado de
imágenes Docker donde vivirá la imagen de la API (`docs/azure-container-apps-deploy.md` la creaba
manualmente vía `az acr create`). Container Apps (bloques futuros) hará `pull` de esa imagen desde
ahí.

Por qué después del Resource Group: ACR necesita un `resource_group_name`/`location` existentes;
el módulo `acr` toma esos valores de `module.resource_group[0]`, y `create_acr=true` está validado
para exigir `create_resource_group=true`.

Decisiones clave (ver también la sección [Decisiones técnicas](#decisiones-técnicas-resumen)):

- `admin_enabled=false`: el diseño futuro preferirá Managed Identity + rol `AcrPull`, no
  credenciales de admin.
- `sku="Basic"`: suficiente para dev/portfolio, minimiza costo cuando se cree.
- Naming: ACR es global, sin guiones/mayúsculas, 5–50 caracteres. Se agregó `var.unique_suffix`
  (vacío por default) para poder desambiguar el nombre sin usar `random_string` (evita nombres no
  deterministas).

Cambios de archivos:

- `modules/acr/{main,variables,outputs}.tf` — nuevo módulo real; crea únicamente
  `azurerm_container_registry`.
- `environments/dev/versions.tf` — `required_version` a `>= 1.9.0`.
- `environments/dev/variables.tf` — `create_acr` con validación cruzada, más `acr_sku`,
  `acr_admin_enabled`, `unique_suffix`.
- `environments/dev/locals.tf` — `acr_name` incorpora `unique_suffix` y se trunca a 50 caracteres.
- `environments/dev/main.tf` — `module "acr"` gateado por `create_acr`.
- `environments/dev/outputs.tf` — `acr_enabled`, `acr_name`, `acr_id`, `acr_login_server` (seguros
  con `create_acr=false`).
- `environments/dev/terraform.acr.example.tfvars` — nuevo, previsualiza Resource Group + ACR.

Comandos de validación:

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate

# Sólo Resource Group (ya en state): sin cambios
terraform plan -var-file="terraform.resource-group.example.tfvars"

# Resource Group + ACR: 1 recurso nuevo
terraform plan -var-file="terraform.acr.example.tfvars"
```

### Resultados observados

`terraform fmt -recursive -check`, `terraform init` y `terraform validate` (Terraform v1.13.5,
`azurerm` v4.80.0) pasaron sin errores.

Plan con `terraform.resource-group.example.tfvars` (Resource Group ya en state desde el Bloque
4.6): sin cambios de recursos, solo nuevos valores de output (`acr_enabled = false`,
`acr_name = "acrfittrackaidev"`) porque esos outputs no existían antes en el state.

Plan con `terraform.acr.example.tfvars` (`unique_suffix = "dev01"`):

```text
# module.acr[0].azurerm_container_registry.this will be created
  + admin_enabled       = false
  + location            = "eastus"
  + name                = "acrfittrackaidevdev01"
  + resource_group_name = "rg-fittrack-ai-dev"
  + sku                 = "Basic"

Plan: 1 to add, 0 to change, 0 to destroy.
```

Único recurso nuevo: `module.acr[0].azurerm_container_registry.this`. No aparece Key Vault,
PostgreSQL, Container Apps, Managed Identities, VNet ni Log Analytics.

Backend: `uv run ruff check .` → `All checks passed!`. `uv run pytest` no se corrió porque el
Docker daemon local estaba inactivo (mismo caso que el Bloque 4.6); no se modificó código de
backend en este bloque, así que no hay regresión que verificar con pytest.

**No se ejecutó `terraform apply` en este bloque. No se creó ningún ACR real.**

## Block 4.8 — ACR Apply

Status: **completed**

Created resources:

- Azure Container Registry (`acrfittrackaidevdev01`, SKU `Basic`, `admin_enabled=false`)

Terraform state:

```text
module.resource_group[0].azurerm_resource_group.this
module.acr[0].azurerm_container_registry.this
```

No other Azure services were created.

Por qué ACR se creó después del Resource Group: `create_acr=true` está validado para exigir
`create_resource_group=true` — ACR necesita un contenedor lógico (`resource_group_name`/`location`)
que ya exista. Por qué `admin_enabled=false`: evita credenciales estáticas de admin embebidas en
ningún lado; el acceso desde Container Apps usará Managed Identity + rol `AcrPull` en un bloque
futuro. Por qué `sku="Basic"`: suficiente para dev/portfolio, minimiza costo. Por qué no se hizo
push de imágenes todavía: separa deliberadamente la infraestructura (el registro) de los
artefactos (las imágenes), que llegan en el Bloque 4.9. Por qué no se configuró `AcrPull` todavía:
requiere una Managed Identity que aún no existe.

### Comandos ejecutados

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate
terraform plan -var-file="terraform.acr.example.tfvars"
terraform apply -var-file="terraform.acr.example.tfvars"   # confirmado manualmente con "yes"
```

No se usó `-auto-approve`.

### Resultado del plan

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Único recurso planeado: `module.acr[0].azurerm_container_registry.this`.

### Resultado del apply

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

### Outputs relevantes

```text
acr_enabled      = true
acr_name         = "acrfittrackaidevdev01"
acr_id           = "/subscriptions/<subscription-id>/resourceGroups/rg-fittrack-ai-dev/providers/Microsoft.ContainerRegistry/registries/acrfittrackaidevdev01"
acr_login_server = "acrfittrackaidevdev01.azurecr.io"
```

### Verificación

- `terraform state list` → exactamente `module.resource_group[0].azurerm_resource_group.this` y
  `module.acr[0].azurerm_container_registry.this`.
- `az acr show --name "$(terraform output -raw acr_name)" --resource-group
  "$(terraform output -raw resource_group_name)" --query "{name:name, sku:sku.name,
  adminUserEnabled:adminUserEnabled, loginServer:loginServer}" -o json` → confirma
  `sku=Basic`, `adminUserEnabled=false`, `loginServer=acrfittrackaidevdev01.azurecr.io`.
- Backend: `uv run ruff check .` → `All checks passed!`. `uv run pytest` no se corrió porque el
  Docker daemon local estaba inactivo (mismo caso que los Bloques 4.6 y 4.7); no se modificó código
  de backend en este bloque.

### Docker image push preparation

ACR ya está disponible como el registro privado para las imágenes del backend de FitTrack AI.

ACR actual:

```bash
terraform output -raw acr_name
terraform output -raw acr_login_server
```

Comando futuro de login:

```bash
az acr login --name "$(terraform output -raw acr_name)"
```

Build futuro de la imagen desde la raíz del repo:

```bash
docker build -f backend/Dockerfile -t fittrack-api:local backend
```

Tag futuro de la imagen:

```bash
docker tag fittrack-api:local "$(terraform output -raw acr_login_server)/fittrack-api:latest"
```

Push futuro:

```bash
docker push "$(terraform output -raw acr_login_server)/fittrack-api:latest"
```

**No se hace push de imágenes hasta el Bloque 4.9 dedicado.**

### Destroy ACR

Para destruir el ACR preservando el Resource Group:

```hcl
create_resource_group = true
create_acr            = false
```

```bash
terraform plan -var-file="terraform.resource-group.example.tfvars"
terraform apply -var-file="terraform.resource-group.example.tfvars"
```

Resultado esperado:

```text
Plan: 0 to add, 0 to change, 1 to destroy.
```

**Warning:** destruir el ACR borra las imágenes de contenedor que se hayan hecho push. En esta
etapa no se ha hecho push de ninguna imagen todavía.

`terraform destroy` **no se ha ejecutado** — el ACR sigue activo.

## Block 4.9 — Docker Build, Tag & Push to ACR

Status: **completed**

Published image:

```text
acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9
```

Sin cambios de infraestructura: `terraform state list` sigue mostrando exactamente los mismos
dos recursos del Bloque 4.8 (`module.resource_group[0]` y `module.acr[0]`); no se ejecutó
`terraform apply` ni `terraform destroy`.

Por qué el push se separa de la creación del ACR: mantiene los cambios auditables — la
infraestructura (registro) y el artefacto (imagen) evolucionan en commits/bloques distintos.
Por qué `az acr login` en vez de admin user: `admin_enabled=false` en el ACR, así que el acceso
usa la identidad de Azure CLI del operador, no credenciales estáticas. Por qué el tag
`block-4.9` en vez de sólo `latest`: da trazabilidad exacta de qué bloque publicó qué imagen;
`latest` por sí solo es ambiguo. Por qué no se crea Container Apps todavía: primero debe existir
una imagen verificable en el registro. Por qué no se configura `AcrPull` todavía: requiere una
Managed Identity que se creará en un bloque posterior.

Desviación respecto al smoke test originalmente planeado: el plan proponía
`DATABASE_URL="sqlite+aiosqlite:///:memory:"`, pero `aiosqlite` no es una dependencia del backend
(la imagen productiva sólo trae el driver `psycopg`), y `JWT_SECRET_KEY` es una variable
requerida por `app/core/config.py` que el plan original no incluía. Se usó en su lugar una URL
con dialecto Postgres (`postgresql+psycopg://u:p@localhost:5432/db`) más `JWT_SECRET_KEY`; como
`/health` no abre conexión a la base de datos (el engine de SQLAlchemy es lazy), la app arranca
y responde sin necesitar un Postgres real.

### Comandos ejecutados

```bash
cd infra/terraform/azure/environments/dev
terraform output -raw acr_name
terraform output -raw acr_login_server
terraform output -raw resource_group_name

az acr show --name "$(terraform output -raw acr_name)" \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --query "{name:name, sku:sku.name, adminUserEnabled:adminUserEnabled, loginServer:loginServer}" \
  -o json

az acr login --name "$(terraform output -raw acr_name)"

cd ../../../../..   # raíz del repo
docker build -f backend/Dockerfile -t fittrack-api:local backend
docker images | grep fittrack-api

docker run --rm -d --name fittrack-smoke -p 8000:8000 \
  -e DATABASE_URL="postgresql+psycopg://u:p@localhost:5432/db" \
  -e JWT_SECRET_KEY="smoke-test-secret" \
  -e AI_PROVIDER="fake" \
  fittrack-api:local
curl -s http://localhost:8000/health
docker stop fittrack-smoke

docker tag fittrack-api:local acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9
docker push acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9

az acr repository list --name "$(terraform output -raw acr_name)" -o table
az acr repository show-tags --name "$(terraform output -raw acr_name)" \
  --repository fittrack-api -o table

cd infra/terraform/azure/environments/dev
terraform state list
terraform plan -var-file="terraform.acr.example.tfvars"
```

### Resultado del Docker build

Build exitoso (mayoría de capas cacheadas desde el Bloque 4.1):
`naming to docker.io/library/fittrack-api:local done`. Imagen local confirmada con
`docker images` (261MB).

### Resultado del smoke test

```json
{"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

HTTP 200, sin necesitar un Postgres real corriendo (el healthcheck del contenedor sondea el
mismo endpoint).

### Resultado del ACR login

```text
Login Succeeded
```

### Resultado del Docker push

```text
block-4.9: digest: sha256:f9ee45d4651f8b89a698c615ef3dc7c62ea76496e4812ee1ab0a9bbe9403a04d size: 1785
```

### Verificación

- `az acr repository list` → `fittrack-api`.
- `az acr repository show-tags --repository fittrack-api` → `block-4.9`.
- `terraform state list` → sólo `module.resource_group[0].azurerm_resource_group.this` y
  `module.acr[0].azurerm_container_registry.this` (sin cambios respecto al Bloque 4.8).
- `terraform plan -var-file="terraform.acr.example.tfvars"` → `No changes. Your infrastructure
  matches the configuration.`
- Backend: `uv run ruff check .` → `All checks passed!`. `uv run pytest` corrió contra el
  Postgres local de `backend/docker-compose.yml` (servicio `db`, puerto 5433) → `66 passed`.

**No se ejecutó `terraform apply` ni `terraform destroy` en este bloque. No se creó Container
Apps, Managed Identity, AcrPull, Key Vault, PostgreSQL en Azure, networking ni monitoring.**

## Block 4.10 — Terraform Container Apps Environment Module Plan

Status: **completed** (implementación y planificación; sin `apply`).

Qué es Log Analytics Workspace: el destino de logs/métricas de Azure Monitor; Container Apps
Environment lo requiere para observabilidad desde el primer momento. Qué es Container Apps
Environment: el runtime compartido donde vivirán las Container Apps (bloques futuros) — análogo a
un "clúster" lógico de Container Apps.

Por qué Log Analytics antes del Environment: `azurerm_container_app_environment` requiere
`log_analytics_workspace_id` en su creación. Por qué el Environment antes de la Container App
real: primero se valida el runtime compartido; la Container App llega después de tener el
Environment probado. Por qué sólo `plan` y no `apply`: separa deliberadamente la implementación
del módulo de la creación real de recursos, igual que en los Bloques 4.4/4.5 y 4.7.

**Desviación intencional respecto al diseño inicialmente esbozado:** `azurerm_container_app_environment`
toma `log_analytics_workspace_id` como el **resource ID** del workspace (`module.monitoring[0].id`)
— no existe ningún argumento de shared key en ese recurso; el provider maneja la autenticación
internamente. Por eso `modules/container_apps_environment` no recibe ni `workspace_id`
(customer ID) ni `primary_shared_key` como inputs. El módulo `monitoring` sí expone ambos como
outputs (`workspace_id`, `primary_shared_key` sensible) para uso futuro, pero **no** se exponen
como outputs del entorno `dev`. Confirmado corriendo `terraform validate` contra `azurerm v4.80.0`.

Cambios de archivos:

- `modules/monitoring/{main,variables,outputs}.tf` — nuevo módulo real; crea únicamente
  `azurerm_log_analytics_workspace`.
- `modules/container_apps_environment/{main,variables,outputs}.tf` — nuevo módulo real; crea
  únicamente `azurerm_container_app_environment`.
- `environments/dev/variables.tf` — `create_monitoring` con validación cruzada
  (`create_resource_group`), `create_container_apps_environment` con dos validaciones cruzadas
  (`create_resource_group` y `create_monitoring`), más `log_analytics_sku` y
  `log_analytics_retention_in_days`.
- `environments/dev/main.tf` — `module "monitoring"` y `module "container_apps_environment"`
  gateados por sus flags respectivos.
- `environments/dev/outputs.tf` — `monitoring_enabled`, `log_analytics_workspace_name`,
  `log_analytics_workspace_id`, `container_apps_environment_enabled`,
  `container_apps_environment_name`, `container_apps_environment_id`,
  `container_apps_environment_default_domain` (todos seguros con los módulos desactivados).
  `primary_shared_key` no se expone como output del entorno.
- `environments/dev/terraform.container-apps-env.example.tfvars` — nuevo, previsualiza Resource
  Group + ACR + Monitoring + Container Apps Environment.
- `environments/dev/locals.tf` — sin cambios (`log_analytics_workspace` y
  `container_app_env_name` ya existían desde el Bloque 4.3).

Comandos de validación:

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate

# Sólo Resource Group + ACR (ya en state): sin cambios de recursos
terraform plan -var-file="terraform.acr.example.tfvars"

# + Monitoring + Container Apps Environment: 2 recursos nuevos
terraform plan -var-file="terraform.container-apps-env.example.tfvars"
```

### Resultados observados

`terraform fmt -recursive -check`, `terraform init` y `terraform validate` (Terraform v1.13.5,
`azurerm` v4.80.0) pasaron sin errores.

Plan con `terraform.acr.example.tfvars` (Resource Group + ACR ya en state): `0 to add, 0 to
change, 0 to destroy` — solo aparecen nuevos valores de output (`monitoring_enabled = false`,
`container_apps_environment_enabled = false`, etc.) porque esos outputs no existían antes en el
state.

Plan con `terraform.container-apps-env.example.tfvars`:

```text
# module.container_apps_environment[0].azurerm_container_app_environment.this will be created
  + location                   = "eastus"
  + log_analytics_workspace_id = (known after apply)
  + name                       = "cae-fittrack-ai-dev"
  + resource_group_name        = "rg-fittrack-ai-dev"

# module.monitoring[0].azurerm_log_analytics_workspace.this will be created
  + location            = "eastus"
  + name                = "log-fittrack-ai-dev"
  + resource_group_name = "rg-fittrack-ai-dev"
  + retention_in_days   = 30
  + sku                 = "PerGB2018"

Plan: 2 to add, 0 to change, 0 to destroy.
```

Únicos recursos nuevos: `module.monitoring[0].azurerm_log_analytics_workspace.this` y
`module.container_apps_environment[0].azurerm_container_app_environment.this`. No aparece
`azurerm_container_app`, `azurerm_user_assigned_identity`, `azurerm_role_assignment`,
`azurerm_key_vault`, `azurerm_postgresql_flexible_server`, `azurerm_virtual_network` ni
`azurerm_subnet`.

Backend: `uv run ruff check .` → `All checks passed!`. Docker estaba activo; se levantó el
Postgres de `backend/docker-compose.yml` (servicio `db`) y `uv run pytest` → `66 passed`. No se
modificó código de backend en este bloque.

**No se ejecutó `terraform apply` en este bloque. No se creó Log Analytics Workspace ni Container
Apps Environment reales. No se creó Container App, Managed Identity, AcrPull, Key Vault,
PostgreSQL ni networking privado.**

## Block 4.11 — Container Apps Environment Apply

Status: **completed**

Created resources:

- Log Analytics Workspace (`log-fittrack-ai-dev`, SKU `PerGB2018`, retención 30 días)
- Azure Container Apps Environment (`cae-fittrack-ai-dev`)

Terraform state:

```text
module.resource_group[0].azurerm_resource_group.this
module.acr[0].azurerm_container_registry.this
module.monitoring[0].azurerm_log_analytics_workspace.this
module.container_apps_environment[0].azurerm_container_app_environment.this
```

No se creó Container App, Managed Identity, AcrPull, Key Vault, PostgreSQL ni networking privado.

Por qué Log Analytics antes del Environment: `azurerm_container_app_environment` requiere
`log_analytics_workspace_id` en su creación (ver decisión #18 más abajo). Por qué el Environment
antes de la Container App real: primero se valida el runtime compartido; el Bloque 4.12
implementará el módulo `container_apps` sobre esta base ya probada.

### Comandos ejecutados

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate
terraform plan -var-file="terraform.container-apps-env.example.tfvars"
terraform apply -var-file="terraform.container-apps-env.example.tfvars"   # confirmado manualmente con "yes"
```

No se usó `-auto-approve`. El apply se ejecutó directamente en una terminal interactiva (ver la
nota del Bloque 4.6 sobre por qué el apply real no puede correr vía canales no interactivos).

### Resultado del plan

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Únicos recursos planeados: `module.monitoring[0].azurerm_log_analytics_workspace.this` y
`module.container_apps_environment[0].azurerm_container_app_environment.this`.

### Resultado del apply

```text
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

### Outputs relevantes

```text
monitoring_enabled                         = true
log_analytics_workspace_name               = "log-fittrack-ai-dev"
log_analytics_workspace_id                 = "/subscriptions/<subscription-id>/resourceGroups/rg-fittrack-ai-dev/providers/Microsoft.OperationalInsights/workspaces/log-fittrack-ai-dev"

container_apps_environment_enabled         = true
container_apps_environment_name            = "cae-fittrack-ai-dev"
container_apps_environment_id              = "/subscriptions/<subscription-id>/resourceGroups/rg-fittrack-ai-dev/providers/Microsoft.App/managedEnvironments/cae-fittrack-ai-dev"
container_apps_environment_default_domain  = "wittydune-377fa2b0.eastus.azurecontainerapps.io"
```

`default_domain` ya existe con un valor real tras el apply (antes del apply aparecía como
"known after apply").

### Verificación

- `terraform state list` → exactamente los 4 recursos listados arriba (Resource Group, ACR, Log
  Analytics Workspace, Container Apps Environment). Sin otros recursos.
- `az monitor log-analytics workspace show --resource-group "$(terraform output -raw
  resource_group_name)" --workspace-name "$(terraform output -raw log_analytics_workspace_name)"
  --query "{name:name, location:location, sku:sku.name, retentionInDays:retentionInDays}" -o json`
  → confirma `name=log-fittrack-ai-dev`, `location=eastus`, `sku=PerGB2018`,
  `retentionInDays=30`.
- `az containerapp env show --name "$(terraform output -raw container_apps_environment_name)"
  --resource-group "$(terraform output -raw resource_group_name)" --query
  "{name:name, location:location, defaultDomain:properties.defaultDomain,
  provisioningState:properties.provisioningState}" -o json` → confirma
  `name=cae-fittrack-ai-dev`, `provisioningState=Succeeded`, `defaultDomain` coincide con el
  output de Terraform.
- `terraform plan -var-file="terraform.container-apps-env.example.tfvars"` (post-apply) →
  `No changes. Your infrastructure matches the configuration.`
- Backend: `uv run ruff check .` → `All checks passed!`. Se levantó el Postgres local de
  `backend/docker-compose.yml` (servicio `db`, puerto 5433) y `uv run pytest` → `66 passed`. No
  se modificó código de backend en este bloque.

**No se creó Container App, Managed Identity, AcrPull, Key Vault, PostgreSQL en Azure, networking
privado ni secrets. No se ejecutó `terraform destroy`.**

### Destroy Container Apps Environment resources

Para destruir únicamente los recursos de este bloque, preservando Resource Group y ACR, usar el
escenario de ACR donde monitoring y container apps environment quedan deshabilitados:

```bash
cd infra/terraform/azure/environments/dev
terraform plan -var-file="terraform.acr.example.tfvars"
terraform apply -var-file="terraform.acr.example.tfvars"
```

Resultado esperado:

```text
Plan: 0 to add, 0 to change, 2 to destroy.
```

Recursos que se destruirían:

- Azure Container Apps Environment
- Log Analytics Workspace

**Warning:** destruir Log Analytics borra los logs recolectados. Destruir el Container Apps
Environment también afecta a cualquier Container App futura dentro de él. En esta etapa no existe
ninguna Container App todavía.

`terraform destroy` **no se ha ejecutado** — ambos recursos siguen activos.

## Block 4.12 — Container App Module Plan

Status: **completed** (implementación y planificación; sin `apply`).

Qué es la Managed Identity: una identidad de Azure AD asignada por el usuario (User Assigned)
que la Container App usa para autenticarse contra servicios de Azure sin credenciales estáticas.
Por qué se necesita `AcrPull`: el ACR tiene `admin_enabled=false` desde el Bloque 4.7/4.8, así
que la Container App no puede hacer `pull` con usuario/contraseña; el rol `AcrPull` scoped al
ACR le da permiso de lectura sobre el registro usando la identidad. Qué es la Container App:
el recurso que ejecuta el contenedor de la API dentro del Container Apps Environment del Bloque
4.11. Qué imagen se planea desplegar: `acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9`
(ya publicada en el Bloque 4.9).

Por qué Managed Identity antes o junto con la Container App: la Container App necesita la
identidad ya creada (con `AcrPull` ya asignado) para poder hacer `pull` de la imagen privada en
su primera revisión. Por qué sólo `plan` y no `apply`: separa deliberadamente la implementación
del módulo de la creación real de recursos, igual que en los Bloques 4.7 y 4.10.

**Variables temporales de planificación:** el `module.container_apps` en `environments/dev/main.tf`
pasa `env_vars` con `AI_PROVIDER = "fake"` (evita depender de Azure OpenAI en el primer deploy),
`JWT_SECRET_KEY = "dev-only-placeholder-change-before-prod"`, y `DATABASE_URL =
"postgresql+psycopg://placeholder:placeholder@placeholder:5432/fittrack"` (no existe PostgreSQL
real todavía). Estos valores son visibles en el `plan` pero **no se crean en Azure** porque este
bloque no ejecuta `apply`. No son aceptables para producción — un bloque futuro debe moverlos a
Key Vault (`secretref:`) antes de aplicar este módulo.

Cambios de archivos:

- `modules/managed_identities/{main,variables,outputs}.tf` — nuevo módulo real; crea
  `azurerm_user_assigned_identity` y `azurerm_role_assignment` (rol `AcrPull`, scope = ACR).
- `modules/container_apps/{main,variables,outputs}.tf` — nuevo módulo real; crea únicamente
  `azurerm_container_app` (identity `UserAssigned`, `registry` autenticado por esa identidad,
  ingress externo, 100% tráfico a la última revisión, un `container` con `dynamic "env"`).
- `environments/dev/variables.tf` — `create_managed_identities` ahora con dos validaciones
  cruzadas (`create_resource_group`, `create_acr`); `create_container_apps` ahora con cuatro
  validaciones cruzadas (`create_resource_group`, `create_acr`,
  `create_container_apps_environment`, `create_managed_identities`); nuevas variables
  `api_image_tag`, `api_cpu`, `api_memory`, `api_min_replicas`, `api_max_replicas`,
  `api_target_port`.
- `environments/dev/locals.tf` — nuevo local `api_identity_name =
  "id-${var.project_name}-api-${var.environment}"` (reutiliza el `local.container_app_api_name`
  ya existente desde el Bloque 4.3 para la Container App).
- `environments/dev/main.tf` — `module "managed_identities"` y `module "container_apps"`
  gateados por sus flags respectivos, con los placeholders de `env_vars` documentados.
- `environments/dev/outputs.tf` — `managed_identities_enabled`, `api_identity_name`,
  `api_identity_id`, `api_identity_client_id`, `container_apps_enabled`,
  `api_container_app_name`, `api_container_app_id`, `api_container_app_url`,
  `api_container_image` (todos seguros con los módulos desactivados).
- `environments/dev/terraform.container-app.example.tfvars` — nuevo, previsualiza Resource
  Group + ACR + Monitoring + Container Apps Environment + Managed Identity + Container App.

Comandos de validación:

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate

# Estado actual (Resource Group + ACR + Monitoring + CAE ya en state): sin cambios de recursos
terraform plan -var-file="terraform.container-apps-env.example.tfvars"

# + Managed Identity + AcrPull + Container App: 3 recursos nuevos
terraform plan -var-file="terraform.container-app.example.tfvars"
```

### Resultados observados

`terraform fmt -recursive -check`, `terraform init` (registra los dos módulos nuevos) y
`terraform validate` (Terraform v1.13.5, `azurerm` v4.80.0) pasaron sin errores.

Plan con `terraform.container-apps-env.example.tfvars` (los 4 recursos existentes ya en state):
0 cambios de recursos — solo aparecen nuevos valores de output (`managed_identities_enabled =
false`, `container_apps_enabled = false`, etc.) porque esos outputs no existían antes en el state.

Plan con `terraform.container-app.example.tfvars`:

```text
# module.container_apps[0].azurerm_container_app.this will be created
# module.managed_identities[0].azurerm_role_assignment.acr_pull will be created
# module.managed_identities[0].azurerm_user_assigned_identity.this will be created

Plan: 3 to add, 0 to change, 0 to destroy.
```

Únicos recursos nuevos: identidad `id-fittrack-ai-api-dev`, su role assignment `AcrPull`
(scope = ACR del Bloque 4.8), y la Container App `ca-fittrack-ai-api-dev` (imagen
`acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9`). No aparece Key Vault, PostgreSQL,
VNet/subnets, Storage, Container App Job, ni ACR/Resource Group nuevos.

Backend (sin cambios de código): `uv run ruff check .` → `All checks passed!`. Se usó el
Postgres local de `backend/docker-compose.yml` (servicio `db`, puerto 5433, ya estaba corriendo)
y `uv run pytest` → `66 passed`.

**No se ejecutó `terraform apply` ni `terraform destroy` en este bloque. No se creó ninguna
Managed Identity, role assignment ni Container App reales. No se creó Key Vault, PostgreSQL ni
networking privado. No se hizo push de una nueva imagen Docker.**

## Block 4.13 — Container App Apply: API Health Check Demo

Status: **completed**.

Created/validated resources:

- User Assigned Managed Identity for the API (`id-fittrack-ai-api-dev`)
- `AcrPull` role assignment on the private Azure Container Registry (scope = ACR del Bloque 4.8)
- Azure Container App for the FastAPI backend (`ca-fittrack-ai-api-dev`)

Terraform state:

```text
module.resource_group[0].azurerm_resource_group.this
module.acr[0].azurerm_container_registry.this
module.monitoring[0].azurerm_log_analytics_workspace.this
module.container_apps_environment[0].azurerm_container_app_environment.this
module.managed_identities[0].azurerm_user_assigned_identity.this
module.managed_identities[0].azurerm_role_assignment.acr_pull
module.container_apps[0].azurerm_container_app.this
```

Published image used:

```text
acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.13-amd64
```

Por qué un tag nuevo en vez de reusar `block-4.9`: el Bloque 4.9 había publicado sin querer una
imagen `linux/arm64` (build local en Apple Silicon sin `--platform`), que Azure Container Apps
rechaza; este bloque reconstruyó la imagen para `linux/amd64` y la publicó bajo `block-4.13-amd64`
(ver decisión técnica #22).

### Comandos ejecutados

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate
terraform plan -var-file="terraform.container-app.example.tfvars"
terraform apply -var-file="terraform.container-app.example.tfvars"   # confirmado manualmente con "yes"
```

No se usó `-auto-approve`. El apply real se corrió en una terminal interactiva (ver la nota del
Bloque 4.6 sobre `EOF` en canales no interactivos).

### Resultado del plan

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

Únicos recursos planeados: `module.managed_identities[0].azurerm_user_assigned_identity.this`,
`module.managed_identities[0].azurerm_role_assignment.acr_pull` y
`module.container_apps[0].azurerm_container_app.this`.

### Resultado del apply

```text
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

### Public health endpoint

```text
https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health
```

```bash
curl "https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health"
```

```json
{"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

### Verificación

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

Post-apply, `terraform plan -var-file="terraform.container-app.example.tfvars"` muestra:

```text
Terraform has compared your real infrastructure against your configuration and found no
differences, so no changes are needed.
```

Backend (sin cambios de código): `uv run ruff check .` limpio; `uv run pytest` → `66 passed` si
el Docker daemon local está activo.

### Importante

Este es un deployment **demo/dev**. La API es públicamente alcanzable y valida el camino de
deployment cloud-native completo:

```text
Docker image → Private ACR → Managed Identity → AcrPull → Azure Container App → /health
```

Sin embargo, los flujos reales de la aplicación **no son production-ready todavía** porque Key
Vault, secrets reales y Azure PostgreSQL no están configurados — la Container App sigue usando
los placeholders `DATABASE_URL`, `JWT_SECRET_KEY` y `AI_PROVIDER=fake` documentados en el Bloque
4.12, ahora ya aplicados en Azure (no solo visibles en `plan`).

Nota sobre URLs: el output de Terraform (`api_container_app_url`) puede reflejar una URL de
**revisión** (p. ej. `https://ca-fittrack-ai-api-dev--j8xo7f2.wittydune-377fa2b0.eastus.azurecontainerapps.io`).
Para documentación pública/portfolio se usa la URL limpia del FQDN reportado por `az containerapp
show` (`ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io`), que es estable
entre revisiones.

### Destroy Managed Identity + AcrPull + Container App

Para destruir únicamente los recursos de este bloque, preservando Resource Group, ACR, Log
Analytics y Container Apps Environment, usar el escenario donde managed identities y container
apps quedan deshabilitados:

```bash
cd infra/terraform/azure/environments/dev
terraform plan -var-file="terraform.container-apps-env.example.tfvars"
terraform apply -var-file="terraform.container-apps-env.example.tfvars"
```

Resultado esperado:

```text
Plan: 0 to add, 0 to change, 3 to destroy.
```

**Warning:** destruir la Container App corta el acceso público a `/health`. No se ha ejecutado
`terraform destroy` — los 3 recursos siguen activos.

## Block 4.14 — Key Vault + Container App Secrets Plan

Status: **completed** (plan-only — no `terraform apply`).

### Objetivo

Mover el diseño de secretos de placeholders planos en env vars hacia:

```text
Container App → Managed Identity → Key Vault (RBAC) → secret references
```

### Decisiones técnicas

1. Key Vault se introduce **después** del health check demo (Block 4.13) — los placeholders planos
   no son suficientes para flujos reales.
2. **RBAC** (`enable_rbac_authorization = true`), no access policies legacy.
3. La API recibe **`Key Vault Secrets User`**, no permisos administrativos.
4. `JWT_SECRET_KEY` y `DATABASE_URL` pasan a secretos; `AI_PROVIDER=fake` sigue como env var no
   sensible.
5. `DATABASE_URL` sigue siendo placeholder hasta crear Azure PostgreSQL.
6. **Key Vault references directas** en Container App (`key_vault_secret_id` + `identity`) —
   soportadas por azurerm 4.80.0.
7. Secretos demo creados vía Terraform con valores placeholder (demo-only, not production-ready).
8. `create_key_vault = false` por defecto — el stack live no cambia con el tfvars actual.
9. No se ejecuta `apply` en este bloque — implementación separada del despliegue (Block 4.15).
10. No se outputean valores de secretos.

### Recursos implementados (módulo `key_vault`)

- `azurerm_key_vault` con RBAC habilitado
- `azurerm_role_assignment` — `Key Vault Secrets User` para la Managed Identity de la API
- `azurerm_key_vault_secret` — `JWT-SECRET-KEY`, `DATABASE-URL` (demo placeholders)

Nombre planeado del vault: `kvfittrackaidevdev01`.

### Cambios en `container_apps`

- Nuevo input `secrets` — Key Vault references o valores directos
- Nuevo input `secret_env_vars` — env vars vía `secret_name`
- Wiring condicional en `environments/dev/main.tf`: con `create_key_vault=false` se preservan los
  env vars planos del Block 4.13; con `create_key_vault=true` se usan referencias a Key Vault.

### Comandos ejecutados

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate
terraform plan -var-file="terraform.container-app.example.tfvars"
terraform plan -var-file="terraform.key-vault.example.tfvars"
```

Backend (sin cambios de código): `uv run ruff check .` → `All checks passed`. `uv run pytest`
→ `66 passed` (si Docker está activo).

### Resultado del plan — escenario actual (Container App live)

Con `terraform.container-app.example.tfvars` (`create_key_vault = false`):

```text
No changes. Your infrastructure matches the configuration.
```

### Resultado del plan — escenario Key Vault activo

Con `terraform.key-vault.example.tfvars` (`create_key_vault = true`):

```text
Plan: 4 to add, 1 to change, 0 to destroy.
```

Recursos nuevos esperados:

- `module.key_vault[0].azurerm_key_vault.this`
- `module.key_vault[0].azurerm_role_assignment.api_secrets_user`
- `module.key_vault[0].azurerm_key_vault_secret.this["JWT-SECRET-KEY"]`
- `module.key_vault[0].azurerm_key_vault_secret.this["DATABASE-URL"]`

Update in-place esperado:

- `module.container_apps[0].azurerm_container_app.this` — mover `JWT_SECRET_KEY` y `DATABASE_URL`
  de env vars planas a secret references

No debe aparecer: PostgreSQL, VNet, ACR nuevo, Resource Group nuevo, CAE nuevo, Container App
adicional.

### Importante

**No se ejecutó `terraform apply` ni `terraform destroy` en este bloque.** Key Vault y secret
wiring existen solo en código y en el plan de previsualización.

El Terraform runner que ejecute el apply del Block 4.15 necesitará permisos para crear secretos
(p. ej. **Key Vault Secrets Officer**). La Managed Identity de la API solo puede **leer** secretos.

## Block 4.15 — Key Vault Apply + Container App Secret Wiring

Status: **completed**.

### Objetivo

Ejecutar el `terraform apply` autorizado para crear y conectar la capa de secretos en Azure:

```text
Container App → Managed Identity → Key Vault (RBAC) → secret references
```

### Recursos creados

- Azure Key Vault (`kvfittrackaidevdev01`) con RBAC habilitado
- Role assignment `Key Vault Secrets User` para la Managed Identity de la API
- Key Vault secret: `JWT-SECRET-KEY` (demo placeholder)
- Key Vault secret: `DATABASE-URL` (demo placeholder)

### Recursos actualizados

- Azure Container App (`ca-fittrack-ai-api-dev`) — `JWT_SECRET_KEY` y `DATABASE_URL` ahora se
  consumen vía Key Vault-backed secret references (`jwt-secret-key`, `database-url`)

### Terraform state (post-apply)

```text
module.resource_group[0].azurerm_resource_group.this
module.acr[0].azurerm_container_registry.this
module.monitoring[0].azurerm_log_analytics_workspace.this
module.container_apps_environment[0].azurerm_container_app_environment.this
module.managed_identities[0].azurerm_user_assigned_identity.this
module.managed_identities[0].azurerm_role_assignment.acr_pull
module.key_vault[0].azurerm_key_vault.this
module.key_vault[0].azurerm_role_assignment.api_secrets_user
module.key_vault[0].azurerm_key_vault_secret.this["JWT-SECRET-KEY"]
module.key_vault[0].azurerm_key_vault_secret.this["DATABASE-URL"]
module.container_apps[0].azurerm_container_app.this
```

### Comandos ejecutados

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -recursive -check
terraform init
terraform validate
terraform plan -var-file="terraform.key-vault.example.tfvars"
terraform apply -var-file="terraform.key-vault.example.tfvars"   # confirmado manualmente con "yes"
```

No se usó `-auto-approve`.

### Resultado del plan (pre-apply)

```text
Plan: 4 to add, 1 to change, 0 to destroy.
```

### Resultado del apply

El apply se completó en dos pasos: el primero creó Key Vault + role assignment; el segundo, tras
asignar **Key Vault Secrets Officer** al usuario Terraform (requerido por RBAC para crear secretos),
completó secretos + update de Container App.

Resultado final acumulado:

```text
Apply complete! Resources: 4 added, 1 changed, 0 destroyed.
```

### Permisos del Terraform runner

El primer intento de apply falló al crear `azurerm_key_vault_secret` con `403 ForbiddenByRbac`:
el usuario que ejecuta Terraform no tenía permisos para `secrets/getSecret/action`. Se resolvió
asignando **Key Vault Secrets Officer** al usuario en el scope del vault — **sin cambiar a access
policies legacy**. La Managed Identity de la API sigue con solo **Key Vault Secrets User**.

### Verificación

- Key Vault verificado con Azure CLI (`rbacAuthorization: true`)
- Nombres de secretos verificados (`DATABASE-URL`, `JWT-SECRET-KEY`) — **valores no expuestos**
- Role assignment `Key Vault Secrets User` verificado para la MI de la API
- Container App: `provisioningState=Succeeded`, revisión `ca-fittrack-ai-api-dev--0000001`
- `/health` HTTP 200:

```text
https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health
```

```json
{"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

- Logs sin errores de Key Vault reference resolution ni crash loop
- Plan post-apply: sin cambios en infraestructura real (solo drift posible en output
  `api_container_app_url` por nueva revisión)

Backend (sin cambios de código): `uv run ruff check .` → `All checks passed`. `uv run pytest`
→ `66 passed`.

### Decisiones técnicas

1. Key Vault se aplica después del health check demo para endurecer el manejo de secretos.
2. Se usa RBAC y `Key Vault Secrets User` — la API no recibe permisos administrativos.
3. Se verifican nombres de secretos, nunca valores.
4. `DATABASE_URL` sigue siendo placeholder hasta Azure PostgreSQL (Block 4.16+).
5. `JWT_SECRET_KEY` es demo/dev — cambiar antes de producción.
6. `AI_PROVIDER=fake` sigue como env var no sensible.
7. Container App usa Key Vault-backed secret references.
8. No se creó PostgreSQL, networking privado ni Azure OpenAI real.
9. No se usó `-auto-approve`.
10. No se migró a access policies legacy.

### Importante

Los valores actuales de secretos son **demo/dev placeholders**, no production-ready.
`DATABASE_URL` sigue apuntando a un host placeholder hasta que exista Azure PostgreSQL.

### Rollback Key Vault secret wiring

Para revertir al estado demo anterior (env vars planos) y destruir recursos de Key Vault:

```bash
cd infra/terraform/azure/environments/dev
terraform plan -var-file="terraform.container-app.example.tfvars"
terraform apply -var-file="terraform.container-app.example.tfvars"
```

Resultado esperado:

```text
Plan: 0 to add, 1 to change, 4 to destroy.
```

Esto eliminaría Key Vault, secretos y role assignment, y restauraría env vars planos en la
Container App. **No ejecutar salvo rollback intencional.**

## Siguiente paso recomendado

Continuar con **Block 5.1 — Flutter Mobile App Foundation**:

- Crear carpeta `mobile/`, inicializar Flutter, environments, API base URL, navegación y theme.

Alternativas posteriores (deferred):

- **Private Networking Plan** (VNet, Private DNS, acceso privado, NAT Gateway).
- **Observability polish** (Application Insights dashboards y alertas).

Block 5.8 added `modules/blob_storage` (private Storage account + container + RBAC). Enable with
`create_blob_storage = true` and cumulative tfvars; see
[`docs/azure-blob-progress-photos.md`](../../../docs/azure-blob-progress-photos.md).
Cloud release validation (Block 5.10):
[`docs/progress-photos-release-validation.md`](../../../docs/progress-photos-release-validation.md).

Documentación checkpoint: [`docs/backend-cloud-checkpoint.md`](../../../docs/backend-cloud-checkpoint.md).

## Block 4.24 — Backend & Cloud Release Checkpoint

Status: **completed**.

### Objetivo

Cerrar formalmente la fase backend/cloud como checkpoint profesional de portfolio antes de
iniciar Flutter mobile. Sin nuevas features ni `terraform destroy`.

### Alcance completado

1. Verificación Git limpio; secretos locales ignorados y no staged.
2. Runtime cloud validado: `/health` HTTP 200, imagen `block-4.23-amd64`, `AI_PROVIDER=azure`.
3. Terraform drift documentado: example tfvars alineados a `block-4.23-amd64`; no apply (evita downgrade).
4. Documentos creados: checkpoint, demo checklist, teardown, transición Flutter.
5. README y docs existentes alineados con Azure OpenAI real y Flutter como siguiente fase.
6. Bullets de CV/entrevista agregados a `docs/portfolio-demo.md`.

### Estado final cloud

- Imagen: `acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.23-amd64`
- Revisión: `ca-fittrack-ai-api-dev--0000003`
- Azure OpenAI: validado en Block 4.23
- FakeAIProvider: local/test/fallback documentado

### Siguiente fase

**Block 5.1 — Flutter Mobile App Foundation** — ver [`docs/mobile-flutter-transition.md`](../../../docs/mobile-flutter-transition.md).

## Block 4.23 — Azure OpenAI Runtime Verification

Status: **completed**.

### Objetivo

Verificar Azure OpenAI real en runtime cloud para recomendaciones semanales: Key Vault-backed
config, `AI_PROVIDER=azure`, `POST /recommendations/weekly` exitoso.

### Resultado

1. **Terraform apply:** 3 added, 1 changed, 0 destroyed (secretos KV + Container App wiring).
2. **Container App:** `AI_PROVIDER=azure`, revisión `ca-fittrack-ai-api-dev--0000003`.
3. **Imagen:** `block-4.23-amd64` (fix `temperature` para `gpt-5-mini`).
4. **Smoke test cloud:** HTTP 201 en `POST /recommendations/weekly`; persistencia PostgreSQL OK.
5. Demo user: `cloud-azure-openai-20260709220923@example.com`.

### Fix backend (gpt-5-mini)

`gpt-5-mini` no acepta `temperature=0.4` (solo default). Se eliminó `temperature` del call en
`backend/app/services/ai_provider.py`. Imagen publicada como `block-4.23-amd64`.

### Alcance completado

1. Variables Terraform: `api_ai_provider`, `api_azure_openai_*`.
2. `locals.tf` / `main.tf`: secretos KV + wiring Container App condicional.
3. `terraform.azure-openai.example.tfvars` + `terraform.azure-openai.local.tfvars` (gitignored).
4. Apply manual con credenciales reales.
5. Docker build/push `block-4.23-amd64` + `az containerapp update`.
6. Documentación actualizada.

### Decisiones técnicas

1. **`AI_PROVIDER=azure`** (no `azure_openai`) — coincide con backend existente.
2. **No se crea recurso Azure OpenAI en Terraform** — solo wiring de config existente.
3. **Secretos sensibles en Key Vault** — endpoint, API key, deployment; API version como env plano.
4. **Sin `temperature` en Azure call** — compatibilidad con modelos reasoning (`gpt-5-mini`).
5. **FakeAIProvider** permanece como fallback documentado vía `terraform.postgres.example.tfvars`.

Runbook: [`docs/azure-openai-runtime.md`](../../../docs/azure-openai-runtime.md).

## Block 4.22 — Portfolio Demo Documentation Polish

Status: **completed**.

### Objetivo

Convertir FitTrack AI en una pieza sólida de portfolio y entrevista técnica: arquitectura,
decisiones, limitaciones, costos/teardown y narrativa — sin modificar infraestructura ni código.

### Alcance completado

1. Creado [`README.md`](../../../README.md) raíz con overview, stack, arquitectura resumida,
   endpoints validados, limitaciones y advertencia de teardown.
2. Creado [`docs/portfolio-demo.md`](../../../docs/portfolio-demo.md) con 16 secciones:
   executive summary, arquitectura (Mermaid), runtime flow (sequence), infra cloud, endpoints,
   decisiones, limitaciones, costos/teardown, narrativa de entrevista.
3. Links cruzados agregados en `backend/README.md`, `docs/cloud-api-smoke-test.md`,
   `docs/docker-production.md`, `docs/azure-container-apps-deploy.md`.
4. Terraform plan final: `No changes`.
5. Backend: ruff limpio; pytest 66 passed.
6. `/health` cloud: HTTP 200.

### Decisiones técnicas

1. **Solo documentación** — sin cambios en Terraform, backend, Dockerfile, Key Vault ni Container App.
2. **README raíz conciso** — vende el proyecto en 1–2 pantallas; detalle en portfolio-demo.
3. **Diagramas Mermaid** — arquitectura (flowchart) y runtime (sequence); primeros del repo.
4. **Key Vault wording correcto** — ACA resuelve secret references al entorno del contenedor;
   la API no llama a Key Vault en cada request.
5. **Sin duplicación excesiva** — docs existentes linkean a portfolio-demo, no repiten contenido.
6. **Sin secretos** — no tokens, passwords ni `DATABASE_URL` en documentación.

### Verificación post-documentación

- Terraform plan: `No changes`.
- Backend: `uv run ruff check .` → All checks passed; `uv run pytest` → 66 passed.
- `/health` cloud: HTTP 200.
- No se ejecutó `terraform apply`, `terraform destroy`, `docker build`, `docker push` ni Alembic.

Portfolio demo: [`docs/portfolio-demo.md`](../../../docs/portfolio-demo.md).

## Block 4.21 — Cloud API Functional Smoke Test

Status: **completed**.

### Objetivo

Validar que la API desplegada en Azure Container Apps funciona end-to-end más allá de `/health`
y auth, usando PostgreSQL real, secretos desde Key Vault, schema Alembic ya migrado y
`FakeAIProvider` para recomendaciones — sin modificar infraestructura ni backend.

### Alcance completado

1. Baseline Terraform plan: `No changes`.
2. Smoke test HTTP contra URL canónica con usuario demo nuevo.
3. Flujo completo: auth → measurements → nutrition (3 fechas) → workout plan/log → weekly
   summary → AI recommendation.
4. Persistencia verificada en Azure PostgreSQL vía Key Vault (conteos por usuario demo).
5. Logs Container App revisados: sin errores críticos DB/KV/SQLAlchemy.
6. Terraform plan final: `No changes`.
7. Backend: `uv run ruff check .` limpio; `uv run pytest` 66 passed.
8. Documentación actualizada.

### Decisiones técnicas

1. **Bloque de verificación + docs** — no se modificó Terraform, backend, Dockerfile, Alembic,
   Key Vault ni Container App config.
2. **Paths reales del backend** — `GET /auth/me` (no `/users/me`); `/measurements` (no
   `/body-measurements`).
3. **Payloads alineados a schemas Pydantic** — `name` en register; `weight`/`waist`/`body_fat_estimate`;
   `protein`/`carbs`/`fats`; workout plan con `day_of_week`, `title`, `muscle_group`,
   `target_sets`, `target_reps`; workout log con `performed_at`, `sets`, `reps`.
4. **Readiness AI** — ≥1 workout log, ≥3 nutrition logs (fechas distintas), ≥1 measurement en la
   semana; `is_ready_for_ai_recommendation=true` confirmado.
5. **`AI_PROVIDER=fake`** — recomendaciones determinísticas sin Azure OpenAI.
6. **Token en variable local** — no documentado ni impreso.
7. **Verificación DB** — firewall temporal `temp-local-smoke-verify` vía Azure CLI, `DATABASE_URL`
   desde Key Vault sin imprimir, conteos seguros, regla eliminada al finalizar.
8. **Alembic no re-ejecutado** — schema ya aplicado en Block 4.18.
9. **Private networking diferido** — hardening en bloque futuro.

### Usuario demo

```text
cloud-smoke-20260709081125@example.com
```

Fecha de ejecución: `2026-07-09T14:11:25Z`.

### Resultados por endpoint

| Área         | Endpoint                        | Resultado |
| ------------ | ------------------------------- | --------- |
| Health       | GET /health                     | HTTP 200  |
| Auth         | POST /auth/register             | HTTP 201  |
| Auth         | POST /auth/login                | HTTP 200  |
| User         | GET /auth/me                    | HTTP 200  |
| Measurements | POST /measurements              | HTTP 201  |
| Measurements | GET /measurements               | HTTP 200  |
| Measurements | GET /measurements/progress      | HTTP 200  |
| Nutrition    | POST /nutrition-logs (×3)       | HTTP 201  |
| Nutrition    | GET /nutrition-logs             | HTTP 200  |
| Nutrition    | GET /nutrition-logs/summary     | HTTP 200  |
| Workouts     | POST /workout-plans             | HTTP 201  |
| Workouts     | GET /workout-plans              | HTTP 200  |
| Workouts     | GET /workout-plans/{id}         | HTTP 200  |
| Workouts     | POST /workout-logs              | HTTP 201  |
| Workouts     | GET /workout-logs               | HTTP 200  |
| Workouts     | GET /workout-logs/summary       | HTTP 200  |
| Weekly       | GET /weekly-summary             | HTTP 200  |
| AI           | POST /recommendations/weekly    | HTTP 201  |
| AI           | GET /recommendations/latest     | HTTP 200  |

### Ajustes de payload vs plan original

- `GET /users/me` → **`GET /auth/me`**
- `/body-measurements` → **`/measurements`**
- Register: **`name`** (no `full_name`); campo opcional `goal`
- Measurements: **`weight`**, **`waist`**, **`body_fat_estimate`** (no `weight_kg` / `waist_cm` /
  `body_fat_percentage`)
- Nutrition: **`protein`**, **`carbs`**, **`fats`** (no sufijos `_g`)
- Workout plan: **`day_of_week`**, **`title`**, exercises con **`muscle_group`**, **`target_sets`**,
  **`target_reps`**
- Workout log: **`performed_at`**, **`sets`**, **`reps`** (no `date`, `sets_completed`,
  `reps_completed`)

### Persistencia PostgreSQL

Conteos verificados para el usuario demo (sin exponer `DATABASE_URL`):

```text
user_exists=True
body_measurements_count=1
nutrition_logs_count=3
workout_plans_count=1
workout_logs_count=1
ai_recommendations_count=1
```

### Logs Container App

- Sin errores de conexión DB, Key Vault access denied, SQLAlchemy ni provider.
- Requests del smoke test registrados con códigos 200/201 esperados.
- `GET /` → HTTP 404 (esperado; no hay ruta raíz).

### Verificación post-smoke-test

- Terraform plan final: `No changes`.
- Backend: `uv run ruff check .` → All checks passed; `uv run pytest` → 66 passed.
- No se ejecutó `terraform apply`, `terraform destroy`, `alembic upgrade head`, `docker build`
  ni `docker push`.
- No se expusieron tokens, passwords, `DATABASE_URL` ni valores de Key Vault.

Runbook detallado: [`docs/cloud-api-smoke-test.md`](../../../docs/cloud-api-smoke-test.md).

## Block 4.20 — Terraformize PostgreSQL Firewall / ACA Egress

Status: **completed**.

### Objetivo

Traer bajo gestión de Terraform la regla firewall creada manualmente en Block 4.19, usando
`terraform import` sin recrear la regla ni ejecutar `terraform apply`.

### Alcance completado

1. Baseline Terraform: `fmt`, `init`, `validate`, plan inicial `No changes`.
2. Firewall Azure verificado: `allow-aca-egress-01` → `20.237.42.17`.
3. `/health` cloud pre-import: HTTP 200.
4. `terraform.postgres.example.tfvars` actualizado con `postgres_allowed_firewall_rules`.
5. Plan pre-import: `1 to add` (firewall rule).
6. `terraform import` exitoso al address
   `module.postgres_flexible[0].azurerm_postgresql_flexible_server_firewall_rule.this["allow-aca-egress-01"]`.
7. `terraform state list` confirma la regla importada.
8. Plan final: `No changes`.
9. `/health` cloud post-import: HTTP 200.
10. Auth smoke test: `POST /auth/register` 201, `POST /auth/login` 200
    (`cloud-firewall-iac-test-001@example.com`).
11. Logs Container App: sin errores DB/KV.
12. Backend: `uv run ruff check .` limpio; pytest no ejecutado (Docker daemon inactivo).
13. Documentación actualizada.

### Decisiones técnicas

1. **`terraform import` (Opción A)** — reconcilia drift manual sin romper conectividad activa.
2. **Regla ya existía y funcionaba** desde Block 4.19; no se borró ni recreó.
3. **Modelada en `postgres_allowed_firewall_rules`** — Terraform vuelve a ser fuente de verdad.
4. **Sin `terraform apply`** — import alinea state con Azure; plan final limpio.
5. **Sin fallback `0.0.0.0`** — solo egress IP específica `20.237.42.17`.
6. **Sin IP local** — no se agregaron reglas temporales.
7. **Conectividad dev/portfolio-grade** — producción requiere VNet/NAT/private access.
8. **Sin cambios en Container App, Key Vault, backend ni Alembic.**

### Imported firewall rule

```text
allow-aca-egress-01 → 20.237.42.17
```

Reason: permite egress de Azure Container Apps hacia el endpoint público de PostgreSQL en la
arquitectura dev/portfolio actual.

### Import command

```bash
terraform import \
  -var-file="terraform.postgres.example.tfvars" \
  'module.postgres_flexible[0].azurerm_postgresql_flexible_server_firewall_rule.this["allow-aca-egress-01"]' \
  "/subscriptions/<redacted>/resourceGroups/rg-fittrack-ai-dev/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-fittrack-ai-pg-dev01/firewallRules/allow-aca-egress-01"
```

### Verificación post-import

- Terraform state: regla importada con `start_ip_address` y `end_ip_address` = `20.237.42.17`.
- Plan final: `No changes`.
- API cloud: `/health` 200; auth 201/200.
- No se ejecutó `terraform apply` ni `terraform destroy`.
- No se expusieron secretos.

### Importante

Este diseño de red sigue siendo dev/portfolio. Para producción, preferir:

- VNet integration
- stable egress via NAT Gateway
- private PostgreSQL access
- Private DNS

El drift manual de Block 4.19 quedó resuelto en este bloque (ver decisión técnica #3 de
Block 4.19).

## Block 4.19 — Container App Database Runtime Verification

Status: **completed**.

### Objetivo

Verificar que la API en Azure Container Apps conecta a Azure PostgreSQL usando `DATABASE_URL` real
desde Key Vault — sin re-ejecutar migraciones Alembic ni modificar infraestructura Terraform.

### Alcance completado

1. Terraform plan inicial: `No changes`.
2. `/health` cloud: HTTP 200.
3. Secret references verificados (nombres `jwt-secret-key`, `database-url`; env
   `JWT_SECRET_KEY`, `DATABASE_URL`, `AI_PROVIDER`) sin exponer valores.
4. Firewall PostgreSQL revisado: sin reglas activas al inicio (post-cleanup Block 4.18).
5. Egress investigado: Container App `outboundIpAddresses` = `20.237.42.17`; CAE `staticIp` =
   `40.76.174.198` (inbound); CAE `outboundIpAddresses` = null.
6. Regla firewall mínima creada vía Azure CLI: `allow-aca-egress-01` → `20.237.42.17`.
7. `POST /auth/register` cloud → HTTP 201 (`cloud-runtime-test-001@example.com`).
8. `POST /auth/login` cloud → HTTP 200 (bearer token; no documentado).
9. Usuario confirmado en Azure PostgreSQL vía query local segura (Key Vault + regla temporal
   `temp-local-verify`, eliminada tras verificación).
10. Logs Container App: sin errores de Key Vault, DB connection refused, timeout ni SSL.
11. Terraform plan final: `No changes`.
12. Backend: `uv run ruff check .` limpio; pytest no ejecutado (Docker daemon inactivo; sin cambios
    de código).
13. Documentación actualizada.

### Decisiones técnicas

1. **Conectividad dev/portfolio (Opción A)** — firewall mínimo; networking privado diferido.
2. **Regla por egress IP específica** — `allow-aca-egress-01` para `20.237.42.17` (outbound IP del
   Container App). No fue necesario el fallback `0.0.0.0` (Allow Azure services).
3. **Firewall vía Azure CLI, no Terraform** — mantiene `postgres_allowed_firewall_rules = {}` y
   `terraform plan` limpio; drift documentado explícitamente. **Resuelto en Block 4.20** vía
   `terraform import`.
4. **`DATABASE_URL` desde Key Vault** — la API cloud usa secret reference + managed identity.
5. **Alembic no re-ejecutado** — schema ya aplicado en Block 4.18 (HEAD `f16d4cefefc2`).
6. **`/health` no valida DB** — la prueba real es el flujo auth contra PostgreSQL cloud.
7. **Sin exponer secretos** — no se imprimió `DATABASE_URL`, passwords ni bearer tokens.

### Temporary PostgreSQL firewall rule

Una regla firewall se agregó manualmente vía Azure CLI para permitir egress de Azure Container
Apps hacia PostgreSQL.

Rule:

```text
allow-aca-egress-01 → 20.237.42.17
```

Reason:

Azure Container Apps necesita acceso de red al endpoint público de PostgreSQL para la
verificación runtime dev/portfolio.

This is not the final production networking design.

Future hardening should consider:

- VNet integration
- private PostgreSQL access
- Private DNS
- NAT Gateway or stable egress

### Verificación post-runtime

- Container App: `provisioningState=Succeeded`.
- PostgreSQL firewall final: solo `allow-aca-egress-01` (regla local `temp-local-verify` eliminada).
- Auth cloud: register 201, login 200.
- Usuario en DB: `cloud-runtime-test-001@example.com`.
- No se ejecutó `terraform destroy`. No se re-ejecutó Alembic.

## Block 4.18 — Azure PostgreSQL Alembic Migration

Status: **completed**.

### Objetivo

Ejecutar la primera migración Alembic contra Azure PostgreSQL de forma segura, verificar el
esquema creado, y documentar el proceso repetible — sin exponer credenciales ni modificar
Container App.

### Alcance completado

1. Servidor manual `psql-test-centralus` eliminado (no gestionado por Terraform).
2. Regla firewall temporal `temp-local-alembic` creada vía Azure CLI (IP local única).
3. `DATABASE_URL` cargado desde Key Vault (`kvfittrackaidevdev01`) sin imprimir el valor.
4. `uv run alembic upgrade head` ejecutado contra `psql-fittrack-ai-pg-dev01` / `fittrack_ai`.
5. 9 tablas verificadas en Azure PostgreSQL.
6. Validación API local contra DB cloud: `/health` 200, `POST /auth/register` 201,
   `POST /auth/login` 200 (usuario demo `demo-cloud-migration@example.com`).
7. Regla firewall temporal eliminada.
8. Terraform plan final: `No changes`.
9. `/health` cloud: HTTP 200 (sin cambios en Container App).
10. Documentación actualizada.

### Decisiones técnicas

1. **Firewall temporal vía Azure CLI**, no Terraform — mantiene `postgres_allowed_firewall_rules = {}`
   y evita drift en `terraform plan`.
2. **`DATABASE_URL` desde Key Vault** — fuente de verdad post-Block 4.17; no usar outputs sensibles
   en logs.
3. **Fix mínimo en `alembic/env.py`** — escapar `%` en URLs con passwords URL-encoded
   (`replace("%", "%%")`) para compatibilidad con ConfigParser de Alembic.
4. **Sin cambios en Container App** — imagen, secrets y runtime sin modificar.
5. **Private networking diferido** — aceptable para dev/portfolio; hardening en bloque futuro.
6. **Container App aún no conecta a PostgreSQL** — esperado; `/health` no valida DB. Block 4.19.

### Tablas creadas en Azure PostgreSQL

`ai_recommendations`, `alembic_version`, `body_measurements`, `exercises`, `nutrition_logs`,
`users`, `workout_days`, `workout_logs`, `workout_plans` (HEAD: `f16d4cefefc2`).

### Cómo repetir migraciones futuras

```text
1. Obtener IP pública actual (curl https://api.ipify.org)
2. Crear regla firewall temporal vía Azure CLI o postgres_allowed_firewall_rules + terraform apply
3. export DATABASE_URL desde Key Vault (sin imprimir el valor)
4. cd backend && uv run alembic upgrade head
5. Verificar tablas en information_schema
6. Eliminar regla firewall temporal
7. terraform plan -var-file="terraform.postgres.example.tfvars" → No changes
```

### Verificación post-migración

- PostgreSQL: `state=Ready`, version 16, DB `fittrack_ai`.
- Key Vault: `DATABASE-URL` enabled (metadata only).
- Firewall: sin reglas externas tras cleanup.
- Backend: `uv run ruff check .` limpio; `uv run pytest` 66 passed.
- No se ejecutó `terraform destroy`. No se expusieron secretos.

## Block 4.16 — PostgreSQL Flexible Server Module Plan

Status: **completed**.

### Objetivo

Implementar el módulo Terraform real `modules/postgres_flexible` para Azure Database for
PostgreSQL Flexible Server + base de datos `fittrack_ai`, con password generado por Terraform
y outputs sensibles internos (`administrator_password`, `database_url`).

### Alcance

- Módulo real: `random_password`, `azurerm_postgresql_flexible_server`,
  `azurerm_postgresql_flexible_server_database`, firewall rules opcionales (vacías por default).
- Variables postgres en `environments/dev/variables.tf` con validaciones.
- `terraform.postgres.example.tfvars` con `create_postgres=true`.
- Outputs seguros en environment (sin password ni database URL).
- `create_postgres=false` sigue siendo default.
- Plan-only inicialmente; apply autorizado en Block 4.17.

### Decisiones técnicas

1. SKU `B_Standard_B1ms` (~$12–25/mes) para dev/portfolio.
2. Public access + firewall vacío — hardening privado en bloque futuro.
3. Sin VNet, Private DNS, HA, réplicas, connection pooling.
4. Connection string async: `postgresql+psycopg://...?sslmode=require`.
5. Provider `random` agregado en `versions.tf`.

## Block 4.17 — PostgreSQL Apply + DATABASE_URL Secret Update

Status: **completed**.

### Objetivo

Crear PostgreSQL Flexible Server real en Azure, verificar con Azure CLI, y actualizar el
secreto `DATABASE-URL` en Key Vault con el valor real generado por Terraform.

### Recursos creados

| Recurso | Nombre | Región |
|---|---|---|
| PostgreSQL Flexible Server | `psql-fittrack-ai-pg-dev01` | `centralus` |
| Database | `fittrack_ai` | — |
| Key Vault secret update | `DATABASE-URL` | — |

**Nota de región:** la suscripción Azure restringe PostgreSQL Flexible Server en `eastus` y
`eastus2` (`LocationIsOfferRestricted`). PostgreSQL se desplegó en `centralus` via
`postgres_location`, mientras el resto de la infra permanece en `eastus`. El resource group
(`rg-fittrack-ai-dev`) acepta recursos en regiones distintas.

### Applies ejecutados

Dos applies interactivos (sin `-auto-approve`):

| Apply | Plan | Acción |
|---|---|---|
| Apply 1 | `2 to add, 0 to change, 0 to destroy` | Crear PostgreSQL + database + random_password |
| Apply 2 | `0 to add, 1 to change, 0 to destroy` | Actualizar `DATABASE-URL` en Key Vault |

### Wiring DATABASE-URL (Opción A — Terraform)

En `locals.tf`:

```hcl
"DATABASE-URL" = var.create_postgres
  ? module.postgres_flexible[0].database_url
  : var.api_database_url
```

### Verificación post-apply

- PostgreSQL: `state=Ready`, version 16, DB `fittrack_ai` presente.
- Key Vault: secretos `DATABASE-URL` y `JWT-SECRET-KEY` (metadata only, valores no expuestos).
- Container App: `provisioningState=Succeeded`.
- `/health`: HTTP 200 — **no valida conexión PostgreSQL** (correcto para este bloque).

### Decisiones técnicas

1. Dos applies separados para validación intermedia limpia.
2. Wiring Terraform (Opción A) — estado declarativo del secreto.
3. Password generado por Terraform, nunca expuesto en outputs/logs/docs.
4. Alembic **no ejecutado** — queda para Block 4.18.
5. No se usó `-auto-approve`. No se ejecutó `terraform destroy`.
6. `lifecycle { ignore_changes = [zone] }` en el módulo para evitar drift de availability zone.

### Estrategia Alembic (Block 4.18+)

1. Agregar firewall rule temporal para IP local.
2. Obtener `DATABASE_URL` desde Terraform output sensitive (solo local).
3. `uv run alembic upgrade head` contra Azure PostgreSQL.
4. Verificar tablas + endpoints funcionales.
5. Remover firewall temporal si aplica.

### Teardown futuro (no ejecutar casualmente)

```bash
cd infra/terraform/azure/environments/dev
# Revertir wiring DATABASE-URL en locals.tf a var.api_database_url
# Set create_postgres=false, then:
terraform plan -var-file="terraform.key-vault.example.tfvars"
terraform apply -var-file="terraform.key-vault.example.tfvars"
```

Destruye PostgreSQL y restaura placeholder en Key Vault. **No ejecutar salvo rollback intencional.**
