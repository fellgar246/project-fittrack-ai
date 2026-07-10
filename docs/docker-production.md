# Docker — Production API Image (Bloque 4.1)

> **Portfolio demo:** For the cloud architecture overview, validated flows, and interview narrative,
> see [Portfolio Demo](./portfolio-demo.md).

This document describes the **production Docker image** for the FitTrack AI backend
API. The goal of this block is to produce a professional, reproducible, secure and
well-documented container image, ready to be published later to Azure Container
Registry and deployed to Azure Container Apps.

> This block does **not** deploy anything to Azure. It only prepares the image.

All commands below assume you are in the `backend/` directory.

---

## What this image is (and is not)

- It **is** a runtime image for the FastAPI API only.
- It contains **no secrets** and **no `.env` file** — all configuration is injected
  at runtime via environment variables.
- It does **not** run database migrations at startup (see
  [Why migrations are not run at startup](#why-migrations-are-not-run-at-startup)).
- It does **not** include the local dev tooling (`uv`, `pytest`, `ruff`) or the
  test suite — only the runtime virtualenv and the app source.

---

## Local dev vs production image

| | Local development | Production image |
|---|---|---|
| How the API runs | `uv run uvicorn app.main:app --reload` on the **host** | `uvicorn app.main:app` inside the **container** |
| Where Postgres runs | Docker container, published on host `localhost:5433` | Injected via `DATABASE_URL` (Azure DB / compose `db:5432`) |
| Reload | Yes (`--reload`) | No (single stable process) |
| Dependencies | full sync (`uv sync`, includes dev group) | `uv sync --frozen --no-dev` (locked, no dev group) |
| `uv` present | Yes (on the host) | **No** (removed from the runtime stage) |
| User | your host user | non-root `app` user (uid 999) |
| Config source | `.env` file (via pydantic-settings) | **runtime environment variables only** |

The `.env` file is used only for **host-based** commands (`uv run ...`). It is never
copied into the image (it is listed in both `.gitignore` and `.dockerignore`).

---

## Image design

Multi-stage build (`backend/Dockerfile`):

1. **builder** (`python:3.11-slim`)
   - Copies a **pinned** `uv` (0.9.9) from `ghcr.io/astral-sh/uv`.
   - Installs third-party deps first (`uv sync --frozen --no-dev --no-install-project`)
     in a cached layer keyed on `pyproject.toml` + `uv.lock`.
   - Copies the app source and installs the project into `/app/.venv`.
2. **runtime** (`python:3.11-slim`)
   - Creates a non-root `app` user.
   - Copies only `/app` (virtualenv + source) from the builder.
   - Puts `/app/.venv/bin` on `PATH`, so `uvicorn`/`alembic` run **without** `uv`.
   - `EXPOSE 8000`, adds a stdlib `HEALTHCHECK`, and starts uvicorn on `0.0.0.0:8000`.

### Key decisions

- **Reuse the existing base but rewrite it multi-stage** — the previous single-stage
  Dockerfile worked, but shipped `uv`, ran as root and used `uv run` (which re-checks
  the environment on every start). Multi-stage yields a smaller, faster, safer image.
- **One production Dockerfile, no `dev`/`prod` targets** — the real dev loop runs on
  the host with `uv run`; compose reuses this same production image, giving dev/prod
  parity without target complexity.
- **`uv` for reproducible installs** — `uv sync --frozen` installs exactly what
  `uv.lock` pins; `--no-dev` excludes the `dev` dependency group.
- **Python 3.11** — matches `requires-python = ">=3.11"` and the project's `uv.lock`.
- **No `.env` in the image** — secrets must never be baked into an image layer; they
  would leak to anyone who can pull it.
- **Runtime environment variables** — Azure Container Apps injects config as env vars
  / secrets, which is exactly how pydantic-settings already reads configuration.
- **Non-root user** — least privilege; if the process is compromised it does not run
  as root inside the container. Azure Container Apps supports non-root containers.
- **`/health` as the probe endpoint** — cheap, dependency-free liveness signal, ideal
  for a first readiness/liveness check.

---

## Build

```bash
docker build -t fittrack-ai-api:local .
```

BuildKit is used automatically by modern Docker; the `--mount=type=cache` for the uv
cache requires it (Docker Desktop enables it by default).

## Run

The image needs `DATABASE_URL` and `JWT_SECRET_KEY` at runtime; everything else has
safe defaults (`AI_PROVIDER` defaults to `fake`, so no Azure credentials are needed
to boot).

Using an env file (for local testing of the image):

```bash
docker run --rm \
  --name fittrack-ai-api \
  -p 8000:8000 \
  --env-file .env \
  fittrack-ai-api:local
```

Or with explicit runtime variables (no `.env` involved at all):

```bash
docker run --rm \
  --name fittrack-ai-api \
  -p 8000:8000 \
  -e DATABASE_URL='postgresql+psycopg://fittrack:fittrack@host.docker.internal:5433/fittrack' \
  -e JWT_SECRET_KEY='use-a-long-random-value' \
  -e AI_PROVIDER='fake' \
  fittrack-ai-api:local
```

## Health check

```bash
curl http://localhost:8000/health
```

Expected response:

```json
{
  "status": "ok",
  "service": "fittrack-ai-api",
  "version": "0.1.0"
}
```

The image also declares a Docker `HEALTHCHECK` (stdlib `urllib`, since `curl` is not
in the slim base). Check it with:

```bash
docker inspect --format '{{.State.Health.Status}}' fittrack-ai-api
```

Azure Container Apps ignores the Docker `HEALTHCHECK` and uses its own liveness /
readiness probes — point those at `GET /health` on port `8000`.

---

## Environment variables

| Variable | Required | Default | Notes |
|---|---|---|---|
| `DATABASE_URL` | **yes** | — | Must use the `postgresql+psycopg://` scheme (psycopg3 async). |
| `JWT_SECRET_KEY` | **yes** | — | Long random value; never commit it. |
| `JWT_ALGORITHM` | no | `HS256` | |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | no | `60` | |
| `AI_PROVIDER` | no | `fake` | `fake` (no credentials) or `azure`. |
| `AZURE_OPENAI_ENDPOINT` | only if `azure` | `""` | |
| `AZURE_OPENAI_API_KEY` | only if `azure` | `""` | |
| `AZURE_OPENAI_DEPLOYMENT` | only if `azure` | `""` | |
| `AZURE_OPENAI_API_VERSION` | only if `azure` | `""` | |
| `AZURE_OPENAI_TIMEOUT_SECONDS` | no | `20` | |
| `AZURE_OPENAI_MAX_RETRIES` | no | `2` | |
| `APP_NAME` | no | `fittrack-ai-api` | Shown in `/health`. |
| `VERSION` | no | `0.1.0` | Shown in `/health`. |

If `DATABASE_URL` or `JWT_SECRET_KEY` is missing, the app fails fast at startup with a
pydantic `ValidationError` (this is intentional — no silent misconfiguration).

---

## Why migrations are not run at startup

Migrations are deliberately **not** run in the container entrypoint:

- In production, schema changes should be a **controlled, separate step**, not a
  side effect of a process starting.
- With multiple replicas (as in Azure Container Apps autoscale), several instances
  starting at once would try to migrate concurrently — a race condition.
- Keeping migrations separate lets the Azure deploy document them as a pre-deploy
  operation or a dedicated job.

Run migrations explicitly, using the **same image** (alembic is a runtime dependency
and is on the `PATH`):

```bash
# Local host (against Postgres on localhost:5433)
uv run alembic upgrade head

# Or via the production image / compose (against db:5432 internally)
docker compose run --rm api alembic upgrade head
```

---

## Docker Compose (local)

`docker-compose.yml` still works for local development. It runs `db` (Postgres 16,
published on host `5433`) and `api` (built from this Dockerfile).

```bash
# DB only + API on the host (primary dev loop)
docker compose up -d db
uv run alembic upgrade head
uv run uvicorn app.main:app --reload

# Full stack in containers
docker compose up -d
docker compose run --rm api alembic upgrade head   # tables do not auto-create
curl http://localhost:8000/health
docker compose down
```

Inside the compose network the `api` service reaches Postgres at `db:5432` (the
`environment: DATABASE_URL` override), **not** `localhost:5433`. The `5433` mapping is
only for host access.

---

## How this prepares Azure Container Apps

- The image reads **all** config from environment variables — Azure Container Apps
  injects env vars and secrets the same way, with no code changes.
- No secrets are baked in — they will come from Container Apps secrets / Key Vault.
- `/health` is ready to wire to Container Apps liveness/readiness probes.
- Non-root, slim, reproducible image — publishable to Azure Container Registry as-is.
- Migrations are already a separate step, ready to be modeled as a pre-deploy job.

Next block (**4.2**): push to Azure Container Registry and plan the Container Apps
deployment (env vars + secrets).

---

## Build and push to ACR (Block 4.9)

Status: **completed**. Published image:

```text
acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9
```

```bash
# Login (admin user is disabled on the ACR — uses the operator's az CLI identity)
az acr login --name acrfittrackaidevdev01

# Build the production image (from the repo root)
docker build -f backend/Dockerfile -t fittrack-api:local backend

# Tag for ACR and push
docker tag fittrack-api:local acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9
docker push acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.9

# Verify
az acr repository list --name acrfittrackaidevdev01 -o table
az acr repository show-tags --name acrfittrackaidevdev01 --repository fittrack-api -o table
```

The tag is the block name (`block-4.9`), not `latest` — this keeps a clear trail of which
block published which image.

**Smoke test note:** the image requires `JWT_SECRET_KEY` at boot (see
[Environment variables](#environment-variables)) and has no `aiosqlite` driver installed
(only `psycopg`, for Postgres). A local smoke test therefore uses a syntactically valid
Postgres DSN instead of a SQLite one — `/health` never opens a database connection, so the
container boots and answers without a real Postgres running:

```bash
docker run --rm -d --name fittrack-smoke -p 8000:8000 \
  -e DATABASE_URL="postgresql+psycopg://u:p@localhost:5432/db" \
  -e JWT_SECRET_KEY="smoke-test-secret" \
  -e AI_PROVIDER="fake" \
  fittrack-api:local

curl http://localhost:8000/health
# {"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}

docker stop fittrack-smoke
```

No Container App, Managed Identity, or `AcrPull` role assignment exists yet — this block only
publishes the artifact. Terraform state is unchanged by this block.

---

## Deployed to Azure Container Apps (Block 4.13)

The image currently published and deployed is:

```text
acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.13-amd64
```

This is a `linux/amd64` rebuild of the Block 4.9 image — that earlier build ran on Apple Silicon
without `--platform`, producing a `linux/arm64` image that Azure Container Apps rejects. It was
validated live from the Container App (`ca-fittrack-ai-api-dev`) via its public health endpoint:

```bash
curl "https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health"
# {"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

See [`infra/terraform/azure/README.md`](../infra/terraform/azure/README.md#block-413--container-app-apply-api-health-check-demo)
for the full Terraform apply details.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ValidationError: database_url Field required` | `DATABASE_URL` not passed at runtime | Pass `-e DATABASE_URL=...` or `--env-file .env`. |
| `ValidationError: jwt_secret_key Field required` | `JWT_SECRET_KEY` not passed | Pass `-e JWT_SECRET_KEY=...`. |
| API can't connect to Postgres | Wrong host/port in `DATABASE_URL` | Inside Docker use `db:5432`; from the host use `localhost:5433`; from a container to host-Postgres use `host.docker.internal:5433`. |
| `Connection refused` to `localhost:5432` inside container | Used `localhost` inside a container | `localhost` in a container is the container itself — use the service name `db` (or `host.docker.internal`). |
| Confusion between `5433` and `5432` | Host publishes `5433`, container listens on `5432` | Host tools → `5433`; container-to-container → `5432`. |
| `.env not found` | Expecting `.env` inside the image | The image never contains `.env`; pass vars at runtime. |
| `/health` doesn't respond | Container not up yet, or port not published | Check `docker logs`, ensure `-p 8000:8000`, wait for startup. |
| Rebuild seems to do nothing | Docker layer cache | Change is below the cache line, or use `docker build --no-cache`. |
| `driver ... not supported` / DSN error | Wrong DB scheme | Must be `postgresql+psycopg://` (psycopg3), not `postgresql://` or `asyncpg`. |

---

## Known limitations

- No `EntryPoint`/wrapper script — startup is a single `uvicorn` process; migrations
  are run manually.
- `/health` is a liveness signal only; it does **not** check the database. A DB-aware
  readiness endpoint may be added in a later block.
- Single worker (uvicorn default). Scaling is handled by running multiple container
  replicas in Azure Container Apps rather than multiple workers per container.
- No Docker HEALTHCHECK effect in Azure Container Apps (it uses its own probes).
