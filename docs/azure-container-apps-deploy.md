# Azure Container Registry + Container Apps Deploy (Bloque 4.2)

> **Portfolio demo:** For the cloud architecture overview, validated flows, and interview narrative,
> see [Portfolio Demo](./portfolio-demo.md).

This document describes how to publish the FitTrack AI backend image to **Azure
Container Registry (ACR)** and run it as a public HTTP API on **Azure Container
Apps (ACA)**. The goal of this block is to prove the API is no longer local-only:
it becomes a containerized backend running in the cloud, with runtime configuration,
secrets, external ingress, and a `/health` probe.

> This block deploys **only** the API container. It does **not** provision a real
> database, Blob Storage, Application Insights, Terraform, or CI/CD. Those are later
> blocks. The first deploy runs against a *placeholder* `DATABASE_URL` so `/health`
> works; a real database arrives in **Bloque 4.3 — Azure Database for PostgreSQL**.

All `az` commands assume the [Azure CLI](https://learn.microsoft.com/cli/azure/) is
installed and you are logged in. Image build commands assume you are at the **repo
root** (the build context is `./backend`).

---

## 1. Objective

- Store the production Docker image (built in [Bloque 4.1](docker-production.md)) in a
  private registry (ACR).
- Run that image on Azure Container Apps as a serverless container with external
  ingress on port `8000`.
- Inject configuration as environment variables and sensitive values as secrets at
  runtime — never baked into the image.
- Expose a cloud-friendly health check at `GET /health`.
- Provide a reproducible `build → push → deploy → verify` flow, plus logs,
  image-update, and troubleshooting guidance.

## 2. Deploy architecture

```
                 az acr build (cloud build from ./backend)
   ┌────────────┐        │
   │  Your repo │────────┘
   │ ./backend  │
   └────────────┘        ▼
                 ┌──────────────────────────┐
                 │ Azure Container Registry │  acrfittrackaidev.azurecr.io
                 │  fittrack-ai-api:v0.1.0  │
                 └──────────────┬───────────┘
                                │ image pull (Managed Identity → AcrPull)
                                ▼
   Internet ──HTTPS──►  ┌──────────────────────────────────────┐
   GET /health          │ Azure Container Apps Environment       │
                        │  cae-fittrack-ai-dev                   │
                        │  ┌──────────────────────────────────┐  │
                        │  │ Container App: ca-fittrack-ai-api │  │
                        │  │  - ingress: external, port 8000   │  │
                        │  │  - uvicorn app.main:app           │  │
                        │  │  - env vars + secretrefs          │  │
                        │  │  - scale 0..1                     │  │
                        │  └──────────────────────────────────┘  │
                        └──────────────────────────────────────┘
```

The image is built in the cloud by ACR, stored in ACR, and pulled by the Container
App using a **system-assigned managed identity** with the `AcrPull` role — no
registry username/password lives in the app configuration.

## 3. Required Azure resources

| Resource | Purpose |
|---|---|
| Resource Group | Logical container for all resources in this environment. |
| Azure Container Registry (ACR) | Stores the private Docker image. |
| Container Apps Environment | Shared boundary (networking + Log Analytics) for one or more container apps. |
| Container App | Runs the API image with ingress, scaling, env vars, and secrets. |
| Log Analytics workspace | Created automatically with the environment; backs `az containerapp logs`. |

Resource providers that must be registered once per subscription:
`Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.OperationalInsights`.

## 4. Naming convention

Consistent, human-readable names using the pattern `<type>-<project>-<env>`:

| Resource | Name | Constraint notes |
|---|---|---|
| Resource Group | `rg-fittrack-ai-dev` | — |
| ACR | `acrfittrackaidev` | 5–50 chars, **alphanumeric only** (no hyphens), and **globally unique**. If the name is taken, append a short suffix, e.g. `acrfittrackaidev2`. |
| Container Apps Environment | `cae-fittrack-ai-dev` | ≤ 32 chars. |
| Container App | `ca-fittrack-ai-api-dev` | ≤ 32 chars. |
| Image | `fittrack-ai-api` | — |
| Image tag | `v0.1.0` | Always use versioned tags — never `latest` (see §16 and §19.9). |
| Location | `eastus` | — |

> **Why no hyphens in the ACR name?** ACR names become part of the login server DNS
> name (`<name>.azurecr.io`) and Azure restricts them to alphanumeric characters.
> That is why `acrfittrackaidev` drops the hyphens the other names use.

## 5. Shell variables

Set these once per shell session. Everything below references them.

```bash
RESOURCE_GROUP="rg-fittrack-ai-dev"
LOCATION="eastus"
ACR_NAME="acrfittrackaidev"
CONTAINER_APP_ENV="cae-fittrack-ai-dev"
CONTAINER_APP_NAME="ca-fittrack-ai-api-dev"
IMAGE_NAME="fittrack-ai-api"
IMAGE_TAG="v0.1.0"
```

### Login and subscription

```bash
az login
az account show
```

If you have more than one subscription, select the correct one **before creating
anything**:

```bash
az account set --subscription "<subscription-id>"
```

### Register providers (idempotent, once per subscription)

```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.OperationalInsights
```

The `containerapp` extension is installed automatically the first time you run a
`az containerapp` command (or install it explicitly with
`az extension add --name containerapp --upgrade`).

## 6. Build and push the image

### Create the resource group and registry

```bash
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled false
```

Capture the login server (used for tagging and as the registry server):

```bash
ACR_LOGIN_SERVER="$(az acr show \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query loginServer \
  --output tsv)"
echo "$ACR_LOGIN_SERVER"   # e.g. acrfittrackaidev.azurecr.io
```

You can build the image two ways. **Option B (`az acr build`) is recommended** for
this project.

### Option B — ACR build (recommended)

ACR builds the image **in the cloud** from your build context. This avoids CPU
architecture mismatches (Apple Silicon builds `arm64` by default, while ACA runs
`amd64`/`linux`) and does not require a local Docker daemon.

```bash
az acr build \
  --registry "$ACR_NAME" \
  --image "$IMAGE_NAME:$IMAGE_TAG" \
  ./backend
```

### Option A — local build + push (alternative)

Use this only if you specifically want a local build. On Apple Silicon you **must**
force the target platform, or the image will fail to start on ACA:

```bash
az acr login --name "$ACR_NAME"

docker build --platform linux/amd64 -t "$IMAGE_NAME:$IMAGE_TAG" ./backend
docker tag  "$IMAGE_NAME:$IMAGE_TAG" "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
docker push "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
```

Verify the image is in the registry:

```bash
az acr repository show-tags \
  --name "$ACR_NAME" \
  --repository "$IMAGE_NAME" \
  --output table
```

## 7. Create the Container Apps environment

```bash
az containerapp env create \
  --name "$CONTAINER_APP_ENV" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION"
```

This also provisions the backing Log Analytics workspace used by `az containerapp
logs` (§15).

## 8. Create the Container App

The full image reference:

```bash
IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
```

Create the app with external ingress on port `8000`, minimal resources, scale-to-zero,
and a **system-assigned managed identity** used to pull from ACR (see §10):

```bash
az containerapp create \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$CONTAINER_APP_ENV" \
  --image "$IMAGE" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-identity system \
  --target-port 8000 \
  --ingress external \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 0 \
  --max-replicas 1
```

`--registry-identity system` tells ACA to (1) create a system-assigned managed
identity for the app and (2) grant it the `AcrPull` role on the registry, so the
image pull needs no registry password. Secrets and non-sensitive env vars are added
next (§9).

> **Scale-to-zero note.** `--min-replicas 0` means the app scales down when idle, so
> the first request after idle incurs a cold start (a few seconds). For a demo that
> should always answer instantly, use `--min-replicas 1` (higher cost).

## 9. Secrets and environment variables

Configuration is split into **non-sensitive** values (plain env vars) and
**sensitive** values (secrets referenced via `secretref:`).

### Non-sensitive (plain env vars)

| Variable | Value | Notes |
|---|---|---|
| `JWT_ALGORITHM` | `HS256` | Has a default in code; set explicitly for clarity. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | Has a default in code. |
| `AI_PROVIDER` | `fake` | `fake` needs no Azure OpenAI credentials (see §19.6). |
| `AZURE_OPENAI_TIMEOUT_SECONDS` | `20` | Optional; only relevant when `AI_PROVIDER=azure`. |
| `AZURE_OPENAI_MAX_RETRIES` | `2` | Optional; only relevant when `AI_PROVIDER=azure`. |

> **Note on `ENVIRONMENT`.** The current `Settings` class in
> `backend/app/core/config.py` has **no `environment` field**, so setting an
> `ENVIRONMENT` env var has **no effect** today — pydantic-settings silently ignores
> unknown variables. It is intentionally omitted here. Add it only once the code
> actually reads it.

### Sensitive (secrets)

| Variable | Secret name | Notes |
|---|---|---|
| `DATABASE_URL` | `database-url` | Required. Placeholder for now (see below); real value in Bloque 4.3. |
| `JWT_SECRET_KEY` | `jwt-secret-key` | Required. Use a long random value. |
| `AZURE_OPENAI_ENDPOINT` | `azure-openai-endpoint` | Only when `AI_PROVIDER=azure`. |
| `AZURE_OPENAI_API_KEY` | `azure-openai-api-key` | Only when `AI_PROVIDER=azure`. |
| `AZURE_OPENAI_DEPLOYMENT` | `azure-openai-deployment` | Only when `AI_PROVIDER=azure`. |
| `AZURE_OPENAI_API_VERSION` | `azure-openai-api-version` | Only when `AI_PROVIDER=azure`. |

> **Placeholder `DATABASE_URL` for the first deploy.** `DATABASE_URL` is required by
> the app or it fails to start. The engine is created lazily, so a *syntactically
> valid* URL lets the app boot and `/health` respond even without a real database:
>
> ```text
> postgresql+asyncpg://placeholder:placeholder@localhost:5432/fittrack
> ```
>
> Any endpoint that touches the database will fail until Bloque 4.3 wires a real
> Azure Database for PostgreSQL. `/health` does not touch the DB, so it stays green.

### Set secrets, then reference them as env vars

Never print real secret values into docs, terminals-you-share, or the repo. Use
placeholders and generate real values locally.

```bash
# Generate a strong JWT secret locally (do NOT commit it)
JWT_SECRET_KEY="$(openssl rand -hex 32)"
DATABASE_URL="postgresql+asyncpg://placeholder:placeholder@localhost:5432/fittrack"

# 1) Store sensitive values as Container App secrets
az containerapp secret set \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --secrets \
    database-url="$DATABASE_URL" \
    jwt-secret-key="$JWT_SECRET_KEY"

# 2) Set env vars: plain values + secretref: to the secrets above
az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --set-env-vars \
    JWT_ALGORITHM=HS256 \
    ACCESS_TOKEN_EXPIRE_MINUTES=60 \
    AI_PROVIDER=fake \
    DATABASE_URL=secretref:database-url \
    JWT_SECRET_KEY=secretref:jwt-secret-key
```

**Current cloud state (Block 4.23+):** Azure OpenAI is validated in cloud with `AI_PROVIDER=azure`,
Key Vault-backed `azure-openai-*` secrets, and image `block-4.23-amd64`. The snippet below shows
the initial fake-AI deploy pattern from Block 4.13. To switch to Azure OpenAI, add the four
`azure-openai-*` secrets and set `AI_PROVIDER=azure` plus the matching `secretref:` env vars.

## 10. ACR pull access (Managed Identity)

The Container App must authenticate to the private registry to pull the image. Three
options exist; this project uses **Managed Identity**.

| Option | Summary | Verdict |
|---|---|---|
| ACR admin credentials | Enable `--admin-enabled` and store username/password. | Simple, but a shared password lives in config. Fallback only. |
| Service principal | Dedicated app registration with `AcrPull`. | Works, but you manage/rotate another credential. |
| **Managed Identity** | The app's Azure identity is granted `AcrPull`. | **Chosen** — no registry password anywhere. |

**Why Managed Identity is cleaner:** there is no registry username/password to store,
rotate, or leak. Azure manages the identity's lifecycle with the app, and access is
expressed as a role assignment (`AcrPull`) scoped to the registry.

**How it is wired here:** `--registry-identity system` in §8 creates a
system-assigned identity and assigns it the `AcrPull` role on the ACR. To do this
manually (or to verify it):

```bash
# App's system-assigned identity principal id
PRINCIPAL_ID="$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query identity.principalId --output tsv)"

# ACR resource id (the role scope)
ACR_ID="$(az acr show \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id --output tsv)"

# Grant pull
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role AcrPull \
  --scope "$ACR_ID"
```

> Assigning roles requires your account to have `Owner` or `User Access
> Administrator` on the scope. If you lack that permission (or want the fastest
> possible first deploy), use the **admin-credentials fallback**:
>
> ```bash
> az acr update --name "$ACR_NAME" --admin-enabled true
> ACR_USER="$(az acr credential show --name "$ACR_NAME" --query username -o tsv)"
> ACR_PASS="$(az acr credential show --name "$ACR_NAME" --query 'passwords[0].value' -o tsv)"
> az containerapp registry set \
>   --name "$CONTAINER_APP_NAME" \
>   --resource-group "$RESOURCE_GROUP" \
>   --server "$ACR_LOGIN_SERVER" \
>   --username "$ACR_USER" \
>   --password "$ACR_PASS"
> ```
>
> Prefer Managed Identity for anything beyond a throwaway first deploy.

## 11. Health check

The API exposes a simple liveness endpoint:

```text
GET /health  →  200
{"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

- Path: `/health`
- Port: `8000` (matches `--target-port`)
- Type: HTTP

Azure Container Apps already treats a successful response on the ingress target port
as healthy, so no extra probe configuration is required for a first deploy. If you
want explicit probes, add a liveness/readiness HTTP probe on `/health` port `8000`
via a YAML update (`az containerapp update --yaml ...`).

> **What `/health` does and does not prove.** It confirms the process is up and the
> HTTP stack responds. It does **not** check the database or Azure OpenAI. A
> DB-aware health endpoint (e.g. `/health/ready` running `SELECT 1`) can be added
> later — deliberately out of scope here so the first deploy is green without a real
> database.

## 12. Migrations

**Alembic migrations are never run automatically at container startup.** With
`--max-replicas > 1`, multiple replicas starting at once would race on the same
schema. Migrations are a separate, deliberate step.

Strategy (to be exercised for real in Bloque 4.3, once a real database exists):

- **One-off manual run** using the same image (the venv already contains Alembic):
  run `alembic upgrade head` against the target `DATABASE_URL`, for example from a
  local shell with network access to the DB, or via a container job.
- **Container Apps Job** (preferred cloud option later): a job that runs
  `alembic upgrade head` once, triggered manually or before a deploy.
- **CI/CD step** (future): run migrations as a pre-deploy pipeline stage.

Pseudo-command for a one-off job (illustrative — finalized in 4.3):

```bash
az containerapp job create \
  --name "ca-fittrack-ai-migrate-dev" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$CONTAINER_APP_ENV" \
  --image "$IMAGE" \
  --trigger-type Manual \
  --replica-timeout 300 \
  --command "alembic" "upgrade" "head"
# ...plus DATABASE_URL as a secret, then: az containerapp job start ...
```

## 13. Verification

Get the public URL and test `/health`:

```bash
APP_FQDN="$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn \
  --output tsv)"
echo "$APP_FQDN"

curl "https://$APP_FQDN/health"
```

Expected response:

```json
{"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

## 14. Logs

Stream logs:

```bash
az containerapp logs show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --follow
```

List revisions (each config/image change creates a new revision):

```bash
az containerapp revision list \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

## 15. Update the image

Build a new versioned tag and point the app at it (a new revision rolls out):

```bash
IMAGE_TAG="v0.1.1"

az acr build \
  --registry "$ACR_NAME" \
  --image "$IMAGE_NAME:$IMAGE_TAG" \
  ./backend

ACR_LOGIN_SERVER="$(az acr show \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query loginServer \
  --output tsv)"

az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
```

Always bump the tag. Reusing a tag makes it ambiguous which build is running and can
serve a stale cached image (see §19.12).

## 16. Troubleshooting

| # | Symptom | Cause / Fix |
|---|---|---|
| 1 | `az: command not found` | Azure CLI not installed. Install it (`brew install azure-cli`) and re-run `az login`. |
| 2 | Resources created in the wrong subscription | You had multiple subscriptions. Run `az account show`, then `az account set --subscription "<id>"` before creating anything. |
| 3 | ACR name not available | ACR names are globally unique. Pick another, e.g. `acrfittrackaidev2`, and update `$ACR_NAME`. |
| 4 | Push to ACR fails (`unauthorized`) | Run `az acr login --name "$ACR_NAME"` (Option A), or use `az acr build` (Option B) which authenticates for you. |
| 5 | Container App can't pull the image | The managed identity lacks `AcrPull`, or `--registry-server`/`--registry-identity` was not set. Re-check §10; verify the role assignment or use the admin-credential fallback. |
| 6 | App crashes: missing `DATABASE_URL` | `DATABASE_URL` is required. Ensure the `database-url` secret exists and is referenced via `DATABASE_URL=secretref:database-url`. |
| 7 | App crashes: missing `JWT_SECRET_KEY` | Same as above with the `jwt-secret-key` secret. |
| 8 | App does not respond on `/health` | Check `--target-port 8000` matches the container port, view logs (§14), and confirm the image started uvicorn. |
| 9 | Wrong port | ACA routes ingress to `--target-port`; it must be `8000` (the port uvicorn binds and the Dockerfile `EXPOSE`s). |
| 10 | `localhost` in a cloud `DATABASE_URL` | In the cloud, `localhost` points at the container itself, not your DB. Use the DB's real host (set in Bloque 4.3). The placeholder URL is fine only because `/health` never connects. |
| 11 | Confusion between host port `5433` and internal `5432` | The host `5433` mapping is a **local Docker Compose** detail (your Mac already used `5432`). Inside containers and in the cloud, Postgres listens on `5432`. Never put `5433` in a cloud `DATABASE_URL`. |
| 12 | Old image served after update | A reused tag was cached. Always deploy a new tag (`v0.1.1`, …) and confirm with `az containerapp revision list`. |
| 13 | Logs insufficient to diagnose | Use `--follow` (§14), inspect revision status, and check the environment's Log Analytics workspace for system logs. Increase verbosity by reproducing locally with `docker run`. |

## 17. Known limitations

- No real database yet — first deploy uses a placeholder `DATABASE_URL`; only
  non-DB endpoints (like `/health`) work until Bloque 4.3.
- `/health` is liveness-only; it does not verify the DB or AI provider.
- Scale-to-zero (`--min-replicas 0`) means cold starts after idle.
- No custom domain / TLS cert management (uses the default ACA FQDN + managed cert).
- No Application Insights / distributed tracing yet.
- Deploy steps are manual `az` commands — no Terraform or CI/CD.

## 18. Next step

**Bloque 4.3 — Azure Database for PostgreSQL Integration:** provision a managed
Postgres, replace the placeholder `DATABASE_URL` with a real secret, run Alembic
migrations against the cloud DB (one-off job), and validate DB-backed endpoints
end-to-end against the deployed API.

## 19. Technical decisions

1. **ACR over Docker Hub.** The whole stack is Azure; a private ACR keeps the image
   next to the runtime, integrates with Managed Identity for passwordless pulls, and
   avoids Docker Hub rate limits and public exposure.
2. **Container Apps over App Service / AKS.** ACA is serverless containers with
   built-in ingress, revisions, and scale-to-zero — the right altitude for an MVP.
   App Service is more PaaS-opinionated and less container-native; AKS is far more
   operational overhead than a single API needs at this stage.
3. **Secrets/env vars at runtime.** Configuration changes without rebuilding the
   image, and the same image is promotable across environments by swapping config.
4. **No secrets in the image.** A leaked or shared image must never expose
   credentials; secrets live in ACA secrets and are injected at runtime only.
5. **Managed Identity for ACR pull.** No registry password to store, rotate, or
   leak; access is a scoped `AcrPull` role assignment tied to the app's lifecycle.
6. **`AI_PROVIDER=fake` for the first deploy; `azure` for production cloud.** The fake provider
   is deterministic and needs no Azure OpenAI credentials for initial smoke tests. Cloud now runs
   `AI_PROVIDER=azure` (Block 4.23 validated). FakeAIProvider remains for local/test/fallback.
7. **`/health` is enough for the first health check.** It proves the process and
   HTTP stack are alive, which is exactly what a first cloud deploy needs to verify.
8. **No auto-migrate on startup.** Prevents multiple replicas racing on schema
   changes; migrations are an explicit, controlled step.
9. **Versioned image tags.** `v0.1.0`, `v0.1.1`, … make the running build
   unambiguous and rollbacks trivial; `latest` hides which artifact is live.
10. **Prepares Bloque 4.3.** The app already reads `DATABASE_URL` from a secret, so
    integrating Azure Database for PostgreSQL is swapping the placeholder secret for
    a real connection string plus running migrations — no app changes required.
