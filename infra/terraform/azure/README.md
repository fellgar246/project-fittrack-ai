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

**Los bloques 4.3, 4.4, 4.5, 4.7, 4.10 y 4.12 no crean ningún recurso de Azure ni ejecutan
`terraform apply`.** Con todas las banderas `create_*` en `false` (default de
`terraform.tfvars.example`), `terraform plan` no agrega ni cambia ningún recurso — solo calcula
los outputs informativos. Los bloques 4.6, 4.8 y 4.11 son, hasta ahora, los únicos que han
ejecutado un `apply` real: el 4.6 creó el Resource Group, el 4.8 el Azure Container Registry, y
el 4.11 el Log Analytics Workspace y el Container Apps Environment.

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
│       └── README.md             # quickstart del entorno dev
└── modules/
    ├── README.md                 # overview de la capa de módulos
    ├── resource_group/           # módulo real (main/variables/outputs.tf)
    ├── acr/                      # módulo real (main/variables/outputs.tf)
    ├── key_vault/                # placeholder
    ├── managed_identities/       # módulo real (main/variables/outputs.tf)
    ├── networking/                # placeholder
    ├── postgres_flexible/        # placeholder
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
| `create_key_vault` | bool | `false` | Planeado — `modules/key_vault` es placeholder. |
| `create_managed_identities` | bool | `false` | Habilita `module.managed_identities`. Requiere `create_resource_group=true` y `create_acr=true` (validado). |
| `create_networking` | bool | `false` | Planeado — `modules/networking` es placeholder. |
| `create_postgres` | bool | `false` | Planeado — `modules/postgres_flexible` es placeholder. |
| `create_container_apps_environment` | bool | `false` | Habilita `module.container_apps_environment`. Requiere `create_resource_group=true` y `create_monitoring=true` (validado). |
| `create_container_apps` | bool | `false` | Habilita `module.container_apps`. Requiere `create_resource_group=true`, `create_acr=true`, `create_container_apps_environment=true` y `create_managed_identities=true` (validado). |
| `create_monitoring` | bool | `false` | Habilita `module.monitoring`. Requiere `create_resource_group=true` (validado). |
| `log_analytics_sku` | string | `"PerGB2018"` | `Free` o `PerGB2018`. |
| `log_analytics_retention_in_days` | number | `30` | Entre 30 y 730 días. |
| `api_image_tag` | string | `"block-4.9"` | Tag de la imagen del backend ya publicada en ACR. |
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
habilitó `create_resource_group = true`, el Bloque 4.8 `create_acr = true`, y el Bloque 4.11
`create_monitoring = true` y `create_container_apps_environment = true`. Las 5 banderas
restantes (`create_key_vault`, `create_managed_identities`, `create_networking`,
`create_postgres`, `create_container_apps`) siguen en `false`; cada una se activará en su propio
bloque futuro.

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

- No ejecutar `terraform apply` para ningún módulo más allá de `resource_group` (Bloque 4.6),
  `acr` (Bloque 4.8), `monitoring` y `container_apps_environment` (Bloque 4.11).
- No crear Container Apps (la aplicación en sí), PostgreSQL, Blob Storage ni recursos de Azure
  OpenAI vía Terraform.
- No hacer push de imágenes Docker al ACR real (llega en el Bloque 4.9).
- No configurar el rol `AcrPull` todavía (requiere Managed Identity, bloque futuro).
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

## Siguiente paso recomendado

Dos rutas posibles después de este bloque:

- **Opción A — Bloque 4.13: Terraform Container App Apply.** Aplicar los 3 recursos planeados
  (Managed Identity + `AcrPull` + Container App) para que `GET /health` responda públicamente
  desde Azure Container Apps. Limitación: usaría los placeholders temporales de `DATABASE_URL`
  y `JWT_SECRET_KEY` — aceptable solo si se documenta explícitamente como demo/dev, no productivo.
- **Opción B — Bloque 4.13: Key Vault + Secrets Plan.** Antes de aplicar la Container App,
  implementar Key Vault y secrets reales para `JWT_SECRET_KEY` (y definir la estrategia futura
  para `DATABASE_URL`), para no dejar ni siquiera placeholders en configuración aplicada.
