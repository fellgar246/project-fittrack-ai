# FitTrack AI

A cloud-native fitness API demo built to showcase backend engineering, Azure deployment,
infrastructure as code, and applied AI patterns — not a generic fitness app.

**Live API (dev):** `https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io`

```bash
curl "https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health"
# {"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}
```

For the full portfolio narrative — architecture diagrams, validated flows, tradeoffs,
interview talking points, and teardown notes — see **[Portfolio Demo](docs/portfolio-demo.md)**.

---

## What it demonstrates

- **Backend API** — FastAPI, async SQLAlchemy, PostgreSQL, Alembic migrations, JWT auth
- **Cloud deployment** — Docker production image → private ACR → Azure Container Apps
- **Secrets management** — Azure Key Vault with Managed Identity (no static credentials)
- **Infrastructure as Code** — modular Terraform with incremental `create_*` rollout
- **Applied AI** — weekly recommendations via Azure OpenAI in cloud (`fittrack-gpt-5-mini`); `FakeAIProvider` fallback documented
- **End-to-end validation** — 19 cloud endpoints smoke-tested with real PostgreSQL persistence

---

## Tech stack

| Layer | Technologies |
|-------|--------------|
| API | Python 3.11, FastAPI, Pydantic, SQLAlchemy async, Alembic |
| Database | PostgreSQL 16 (Azure Flexible Server) |
| Container | Docker multi-stage, non-root runtime |
| Cloud | Azure Container Apps, ACR, Key Vault, Log Analytics |
| IaC | Terraform (modular, `azurerm` provider) |
| Mobile (planned) | React Native / Expo / TypeScript |

---

## Cloud architecture at a glance

FitTrack AI runs as a FastAPI container on **Azure Container Apps**. The image is stored in a
private **Azure Container Registry** and pulled using a **User Assigned Managed Identity** with
`AcrPull`. Runtime secrets (`DATABASE_URL`, `JWT_SECRET_KEY`) live in **Azure Key Vault** and
are exposed to the app through Key Vault-backed Container App secret references — Azure
resolves them into the container environment before startup. Data persists in **Azure PostgreSQL
Flexible Server**; schema migrations are managed by **Alembic**. Infrastructure is defined with
**Terraform modules** and applied incrementally across 22+ documented blocks.

```
Client → Azure Container Apps (FastAPI)
              ↓ Managed Identity
         Azure Key Vault (secrets)
              ↓
         Azure PostgreSQL (fittrack_ai)
```

---

## Validated API flows (cloud)

| Area | Endpoints | Status |
|------|-----------|--------|
| Health | `GET /health` | HTTP 200 |
| Auth | register, login, `GET /auth/me` | 201 / 200 / 200 |
| Measurements | CRUD + progress | 201 / 200 |
| Nutrition | logs + summary | 201 / 200 |
| Workouts | plans, logs, summaries | 201 / 200 |
| Weekly | `GET /weekly-summary` | 200 (AI-ready) |
| AI | weekly recommendation + latest | 201 / 200 |

Full smoke test runbook: [docs/cloud-api-smoke-test.md](docs/cloud-api-smoke-test.md)

---

## AI capability status

- **Current (cloud):** `AzureOpenAIProvider` — deployment `fittrack-gpt-5-mini` (Block 4.23 validated)
- **Fallback:** `FakeAIProvider` — deterministic, no external API dependency
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

- Mobile app not integrated yet
- Azure OpenAI responses can take ~20–30s (no streaming/timeout tuning yet)
- PostgreSQL uses public endpoint with narrow ACA egress firewall (dev/portfolio compromise)
- No private networking, CI/CD pipeline, custom domain, or load testing
- See [Known limitations](docs/portfolio-demo.md#13-known-limitations) for full list

---

## Documentation map

| Document | Purpose |
|----------|---------|
| [docs/portfolio-demo.md](docs/portfolio-demo.md) | Portfolio overview, architecture, interview narrative |
| [backend/README.md](backend/README.md) | API reference, local dev, migrations |
| [infra/terraform/azure/README.md](infra/terraform/azure/README.md) | Terraform blocks journal (4.1–4.22) |
| [docs/cloud-api-smoke-test.md](docs/cloud-api-smoke-test.md) | Cloud smoke test runbook |
| [docs/docker-production.md](docs/docker-production.md) | Production Docker image |
| [docs/azure-container-apps-deploy.md](docs/azure-container-apps-deploy.md) | ACR + ACA deploy guide |
| [docs/azure-openai-runtime.md](docs/azure-openai-runtime.md) | Azure OpenAI runtime verification (Block 4.23) |

---

## Cost and teardown warning

This demo provisions **real Azure resources** (PostgreSQL, Container Apps, ACR, Key Vault, Log
Analytics) that may incur cost. Do not leave resources running if not needed.

```bash
cd infra/terraform/azure/environments/dev
terraform plan -destroy -var-file="terraform.postgres.example.tfvars"
```

**Do not run `terraform destroy` unless you intentionally want to remove the demo
infrastructure.** Review the plan carefully before confirming. See
[cost and teardown notes](docs/portfolio-demo.md#14-cost-and-teardown-notes).

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

## Next steps

1. **Block 4.24 — Final Portfolio Release** (tag, polish, teardown checklist)
3. **Block 4.24 — Private Networking Plan** (VNet, private PostgreSQL, NAT Gateway)
