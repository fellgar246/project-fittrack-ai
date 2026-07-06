# FitTrack AI — Azure Terraform

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

**Los bloques 4.3, 4.4 y 4.5 no crean ningún recurso de Azure ni ejecutan `terraform apply`.** Con
todas las banderas `create_*` en `false` (default de `terraform.tfvars.example`), `terraform plan`
no agrega ni cambia ningún recurso — solo calcula los outputs informativos. El Bloque 4.6 es el
primero que ejecuta un `apply` real, y lo hace sobre un único recurso (el Resource Group).

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
│       └── README.md             # quickstart del entorno dev
└── modules/
    ├── README.md                 # overview de la capa de módulos
    ├── resource_group/           # ÚNICO módulo real (main/variables/outputs.tf)
    ├── acr/                      # placeholder (solo README.md)
    ├── key_vault/                # placeholder
    ├── managed_identities/       # placeholder
    ├── networking/                # placeholder
    ├── postgres_flexible/        # placeholder
    ├── container_apps_environment/  # placeholder
    ├── container_apps/           # placeholder
    └── monitoring/                # placeholder
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
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

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
| `create_resource_group` | bool | `false` | Habilita `module.resource_group`. Único módulo real hoy. |
| `create_acr` | bool | `false` | Planeado — `modules/acr` es placeholder. |
| `create_key_vault` | bool | `false` | Planeado — `modules/key_vault` es placeholder. |
| `create_managed_identities` | bool | `false` | Planeado — `modules/managed_identities` es placeholder. |
| `create_networking` | bool | `false` | Planeado — `modules/networking` es placeholder. |
| `create_postgres` | bool | `false` | Planeado — `modules/postgres_flexible` es placeholder. |
| `create_container_apps_environment` | bool | `false` | Planeado — `modules/container_apps_environment` es placeholder. |
| `create_container_apps` | bool | `false` | Planeado — `modules/container_apps` es placeholder. |
| `create_monitoring` | bool | `false` | Planeado — `modules/monitoring` es placeholder. |

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
`apply` real solo ocurre cuando un bloque futuro lo autoriza explícitamente. El primero fue el
Bloque 4.6, que habilitó `create_resource_group = true` y creó el Resource Group. Las 8 banderas
restantes siguen en `false`; cada una se activará en su propio bloque futuro.

## 6. Naming conventions

Todos los nombres se derivan en `locals.tf` a partir de `project_name` y `environment`, y ya
están validados contra las reglas de Azure para los recursos que vendrán en bloques futuros:

| Local | Valor (dev) | Regla de Azure |
|---|---|---|
| `resource_group_name` | `rg-fittrack-ai-dev` | ≤90 car., alfanumérico + `-._()` |
| `acr_name` | `acrfittrackaidev` | 5–50 car., solo alfanumérico minúsculas, único global |
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

## 8. State local por ahora

El estado se guarda localmente (`terraform.tfstate`, ignorado por git). Es aceptable para un
proyecto de portfolio de un solo colaborador en esta etapa temprana.

## 9. Por qué no remote state todavía

Remote state (Azure Storage Account + blob container como backend) requiere un recurso de Azure
que primero debe existir — sería crear infraestructura real antes de tener la base lista. Se
implementará en un bloque posterior, una vez exista al menos el Resource Group (Bloque 4.4).

## 10. Por qué no crear recursos costosos todavía

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

- No ejecutar `terraform apply` para ningún módulo más allá de `resource_group` (ya aplicado en
  el Bloque 4.6).
- No crear Azure Container Registry, Container Apps, PostgreSQL, Blob Storage ni recursos de
  Azure OpenAI vía Terraform.
- No configurar remote state.
- No crear Key Vault.
- No configurar GitHub Actions / CI-CD.
- No commitear `terraform.tfvars`, `*.tfstate` ni ningún secreto.
- No hardcodear `subscription_id` ni ninguna credencial en archivos `.tf` o `.tfvars`.
- No ejecutar `terraform destroy` sobre el Resource Group salvo instrucción explícita.

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

## Siguiente paso recomendado

**Bloque 4.7 — Terraform ACR Module Plan**: implementar el módulo `acr` bajo `modules/acr`,
manteniendo `create_acr = false` por default. Permitir previsualizar (`terraform plan`) la
creación del ACR sólo cuando `create_resource_group = true` y `create_acr = true` simultáneamente.
No ejecutar `terraform apply` en este próximo bloque — sólo dejar el módulo listo para recibir
imágenes Docker del backend en bloques posteriores.
