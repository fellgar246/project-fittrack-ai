# FitTrack AI

A cloud-native fitness platform currently validated at the backend and cloud infrastructure
layer. The backend is built with FastAPI, PostgreSQL, Docker, Terraform and Azure, runs on Azure
Container Apps from a private Azure Container Registry, uses Managed Identity and Key Vault for
secure runtime configuration, persists data in Azure PostgreSQL, and generates weekly fitness
recommendations using Azure OpenAI. This backend/cloud checkpoint prepares the project for the
next phase: a Flutter mobile client connected to the validated cloud API.

**Live API (dev):** `https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io`

```bash
curl "https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health"
# {"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

For the full portfolio narrative — architecture diagrams, validated flows, tradeoffs,
interview talking points, and teardown notes — see **[Portfolio Demo](docs/portfolio-demo.md)**.

---

## Current status

FitTrack AI has completed its backend and cloud checkpoint. The FastAPI backend is deployed to
Azure Container Apps, connected to Azure PostgreSQL, configured with Key Vault-managed secrets,
and validated with Azure OpenAI for weekly fitness recommendations.

The Flutter mobile foundation, authentication flow, functional cloud-backed dashboard,
measurements flow, nutrition logs flow, and workout flow are implemented through Block 5.6. The FastAPI backend
remains stable and unchanged during the mobile phase. This is not the final product release.

---

## What it demonstrates

- **Backend API** — FastAPI, async SQLAlchemy, PostgreSQL, Alembic migrations, JWT auth
- **Cloud deployment** — Docker production image → private ACR → Azure Container Apps
- **Secrets management** — Azure Key Vault with Managed Identity (no static credentials)
- **Infrastructure as Code** — modular Terraform with incremental `create_*` rollout
- **Applied AI** — weekly recommendations via Azure OpenAI in cloud (`fittrack-gpt-5-mini`); `FakeAIProvider` for local/test/fallback
- **End-to-end validation** — 19 cloud endpoints smoke-tested with real PostgreSQL persistence

---

## Tech stack

| Layer | Technologies |
|-------|--------------|
| API | Python 3.11, FastAPI, Pydantic, SQLAlchemy async, Alembic |
| Database | PostgreSQL 16 (Azure Flexible Server) |
| Container | Docker multi-stage, non-root runtime |
| Cloud | Azure Container Apps, ACR, Key Vault, Log Analytics, Azure OpenAI |
| IaC | Terraform (modular, `azurerm` provider) |
| Mobile | Flutter (foundation in `mobile/`) |

---

## Cloud architecture at a glance

FitTrack AI runs as a FastAPI container on **Azure Container Apps**. The image is stored in a
private **Azure Container Registry** and pulled using a **User Assigned Managed Identity** with
`AcrPull`. Runtime secrets (`DATABASE_URL`, `JWT_SECRET_KEY`, Azure OpenAI credentials) live in
**Azure Key Vault** and are exposed to the app through Key Vault-backed Container App secret
references — Azure resolves them into the container environment before startup. Data persists in
**Azure PostgreSQL Flexible Server**; schema migrations are managed by **Alembic**. Weekly
recommendations use **Azure OpenAI** (`fittrack-gpt-5-mini`). Infrastructure is defined with
**Terraform modules** and applied incrementally across 24 documented blocks.

```
Client → Azure Container Apps (FastAPI)
              ↓ Managed Identity
         Azure Key Vault (secrets)
              ↓
         Azure PostgreSQL (fittrack_ai)
              ↓
         Azure OpenAI (recommendations)
```

---

## Validated API flows (cloud)

| Area | Endpoints | Status |
|------|-----------|--------|
| Health | `GET /health` | HTTP 200 |
| Auth | register, login, `GET /auth/me` | 201 / 200 / 200 |
| Measurements | list, create, progress | 201 / 200 |
| Nutrition | logs + summary | 201 / 200 |
| Workouts | plans, logs, summaries | 201 / 200 |
| Weekly | `GET /weekly-summary` | 200 (AI-ready) |
| AI | weekly recommendation + latest | 201 / 200 (Azure OpenAI) |

Full smoke test runbook: [docs/cloud-api-smoke-test.md](docs/cloud-api-smoke-test.md)

---

## AI capability status

- **Current (cloud):** `AzureOpenAIProvider` — deployment `fittrack-gpt-5-mini` (Block 4.23 validated)
- **Fallback:** `FakeAIProvider` — deterministic local/test provider; no external API dependency
- **Infrastructure:** Terraform wiring for `AI_PROVIDER=azure` + Key Vault secrets
- **Details:** [docs/azure-openai-runtime.md](docs/azure-openai-runtime.md)

---

## Security notes

- No secrets baked into Docker images
- Key Vault for sensitive runtime configuration
- Managed Identity for ACR pull and Key Vault access (no static passwords)
- JWT bearer auth on protected routes
- Demo uses synthetic data only — no real personal information

---

## Known limitations

- Flutter mobile foundation established in `mobile/` (Block 5.1)
- Mobile auth, dashboard, measurements, nutrition logs, and workouts are implemented
- Azure OpenAI responses can take ~20–30s (no streaming/timeout tuning yet)
- PostgreSQL uses public endpoint with narrow ACA egress firewall (dev/portfolio compromise)
- No private networking, CI/CD pipeline, custom domain, or load testing
- See [Known limitations](docs/portfolio-demo.md#13-known-limitations) for full list

---

## Documentation map

| Document | Purpose |
|----------|---------|
| [docs/portfolio-demo.md](docs/portfolio-demo.md) | Portfolio overview, architecture, interview narrative |
| [docs/backend-cloud-checkpoint.md](docs/backend-cloud-checkpoint.md) | Backend/cloud release checkpoint |
| [docs/backend-cloud-demo-checklist.md](docs/backend-cloud-demo-checklist.md) | Safe demo checklist |
| [mobile/README.md](mobile/README.md) | Flutter mobile client setup and run commands |
| [docs/mobile-flutter-transition.md](docs/mobile-flutter-transition.md) | Flutter mobile transition notes |
| [docs/flutter-auth.md](docs/flutter-auth.md) | Flutter authentication architecture (Block 5.2) |
| [docs/flutter-dashboard.md](docs/flutter-dashboard.md) | Flutter dashboard architecture (Block 5.3) |
| [docs/flutter-measurements.md](docs/flutter-measurements.md) | Flutter measurements architecture (Block 5.4) |
| [docs/flutter-nutrition.md](docs/flutter-nutrition.md) | Flutter nutrition logs architecture (Block 5.5) |
| [docs/flutter-workouts.md](docs/flutter-workouts.md) | Flutter workout flow architecture (Block 5.6) |
| [docs/teardown.md](docs/teardown.md) | Cost control and teardown guide |
| [backend/README.md](backend/README.md) | API reference, local dev, migrations |
| [infra/terraform/azure/README.md](infra/terraform/azure/README.md) | Terraform blocks journal (4.1–4.24) |
| [docs/cloud-api-smoke-test.md](docs/cloud-api-smoke-test.md) | Cloud smoke test runbook |
| [docs/docker-production.md](docs/docker-production.md) | Production Docker image |
| [docs/azure-container-apps-deploy.md](docs/azure-container-apps-deploy.md) | ACR + ACA deploy guide |
| [docs/azure-openai-runtime.md](docs/azure-openai-runtime.md) | Azure OpenAI runtime verification (Block 4.23) |

---

## Cost and teardown warning

This demo provisions **real Azure resources** (PostgreSQL, Container Apps, ACR, Key Vault, Log
Analytics, Azure OpenAI) that may incur cost. Do not leave resources running if not needed.

See [docs/teardown.md](docs/teardown.md) for the teardown guide.

**Do not run `terraform destroy` unless you intentionally want to remove the demo
infrastructure.** Review the plan carefully before confirming.

---

## Local development

```bash
cd backend
uv sync
docker compose up -d db
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

See [backend/README.md](backend/README.md) for full setup.

---

## Flutter mobile dashboard

The authenticated Flutter client now provides a functional dashboard backed by the FitTrack AI
cloud API.

The dashboard presents the current weekly status, recent progress data, the latest AI
recommendation and navigation entry points for measurements, nutrition and workouts. It supports
loading, empty, partial-error and refresh states while reusing the existing secure authentication
session.

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

See [mobile/README.md](mobile/README.md) for platform-specific local API commands,
[docs/flutter-auth.md](docs/flutter-auth.md) for authentication details, and
[docs/flutter-dashboard.md](docs/flutter-dashboard.md) for dashboard contracts and loading
strategy.

## Flutter measurements flow

The Flutter client now supports authenticated body measurement tracking against the FitTrack AI
cloud API. Users can review their measurement history, add new measurements, inspect a progress
summary and refresh the dashboard after recording new data.

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

See [docs/flutter-measurements.md](docs/flutter-measurements.md) for endpoint contracts, units,
loading strategy, and limitations.

## Flutter nutrition logs flow

The Flutter client now supports authenticated nutrition logging against the FitTrack AI cloud API.
Users can review recent nutrition entries, add daily logs, inspect the weekly nutrition summary
and refresh the dashboard readiness state after recording new data.

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

See [docs/flutter-nutrition.md](docs/flutter-nutrition.md) for endpoint contracts, units,
loading strategy, and limitations.

## Flutter workout flow

The Flutter client now supports authenticated workout plan browsing and completed exercise logging
against the FitTrack AI cloud API. Users can review available plans, inspect plan details, record
exercise performance and refresh the weekly dashboard readiness state.

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

See [docs/flutter-workouts.md](docs/flutter-workouts.md) for endpoint contracts, exercise-level
logging semantics, loading strategy, and limitations.

## Next steps

1. **Block 5.7 — Flutter Weekly Summary + AI Recommendation** — dedicated weekly summary screen and
   recommendation generation when backend indicates readiness
2. **Private Networking Plan** (deferred) — VNet, private PostgreSQL, NAT Gateway
3. **Azure Blob Storage** (deferred) — progress photos
4. **Observability polish** (deferred) — Application Insights dashboards and alerts
