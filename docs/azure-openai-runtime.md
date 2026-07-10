# Azure OpenAI Runtime Verification

## Block 4.23 — Azure OpenAI Runtime Verification

Status: **completed**.

Execution date: **2026-07-10T04:09:23Z**.

Demo user: `cloud-azure-openai-20260709220923@example.com`.

Goal: validate real Azure OpenAI runtime integration for weekly recommendations in the cloud API.

## Prerequisites

| Prerequisite | Status |
|--------------|--------|
| Azure OpenAI resource | `test-rg-fittrack-ai-dev` in `rg-fittrack-ai-dev` |
| Deployment | `fittrack-gpt-5-mini` (model `gpt-5-mini`) |
| Key Vault secrets | `AZURE-OPENAI-ENDPOINT`, `AZURE-OPENAI-API-KEY`, `AZURE-OPENAI-DEPLOYMENT` |
| Terraform apply | **3 added, 1 changed, 0 destroyed** |
| Container App revision | `ca-fittrack-ai-api-dev--0000003` (`AI_PROVIDER=azure`) |
| API image | `acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.23-amd64` |

**Important:** backend accepts `AI_PROVIDER=azure` (not `azure_openai`).

## Terraform wiring

Infrastructure code supports `AI_PROVIDER=azure` with Key Vault-backed secrets:

| File | Change |
|------|--------|
| `variables.tf` | `api_ai_provider`, `api_azure_openai_*` variables |
| `locals.tf` | Conditional `AZURE-OPENAI-*` Key Vault secrets |
| `main.tf` | Container App env/secrets wiring for Azure OpenAI mode |
| `terraform.azure-openai.example.tfvars` | Safe example (fake mode, empty Azure OpenAI values) |

### Key Vault secret names

| Key Vault | Container App secret | Env var |
|-----------|---------------------|---------|
| `AZURE-OPENAI-ENDPOINT` | `azure-openai-endpoint` | `AZURE_OPENAI_ENDPOINT` |
| `AZURE-OPENAI-API-KEY` | `azure-openai-api-key` | `AZURE_OPENAI_API_KEY` |
| `AZURE-OPENAI-DEPLOYMENT` | `azure-openai-deployment` | `AZURE_OPENAI_DEPLOYMENT` |

`AZURE_OPENAI_API_VERSION` is a plain (non-secret) env var (`2024-10-21`).

### Apply command

```bash
cd infra/terraform/azure/environments/dev

terraform apply \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars"
```

Create `terraform.azure-openai.local.tfvars` locally (ignored by `*.tfvars` in `.gitignore`):

```hcl
api_ai_provider = "azure"
api_azure_openai_endpoint    = "https://<resource>.openai.azure.com/"
api_azure_openai_api_key     = "<real-key>"
api_azure_openai_deployment  = "<deployment-name>"
api_azure_openai_api_version = "2024-10-21"
```

## Backend fix (gpt-5-mini compatibility)

`gpt-5-mini` rejects non-default `temperature` values. The backend previously sent
`temperature=0.4`, which caused HTTP 502 (`AI provider failed`).

**Fix:** omit `temperature` from the Azure OpenAI `chat.completions.create` call in
`backend/app/services/ai_provider.py` (models use their default).

**Deploy:** image `block-4.23-amd64` built and pushed to ACR; Container App updated via CLI.

## Cloud smoke test results

| Step | Result |
|------|--------|
| `GET /health` | HTTP 200 |
| Seed user + weekly data | HTTP 201 (measurement, nutrition ×3, workout log) |
| `GET /weekly-summary` | `is_ready_for_ai_recommendation=true` |
| `POST /recommendations/weekly` | HTTP **201** (~24s) |
| `GET /recommendations/latest` | HTTP 200 |
| Response content | English, non-deterministic (not FakeAI Spanish) |
| PostgreSQL persistence | Recommendation row saved (`week_start=2026-07-06`) |

### Repeatable smoke test

```bash
API_URL="https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io"
TEST_RUN_ID="$(date +%Y%m%d%H%M%S)"
TEST_EMAIL="cloud-azure-openai-${TEST_RUN_ID}@example.com"
TEST_PASSWORD="DevOnlyTest123!"

# Register, login, seed data (see docs/cloud-api-smoke-test.md), then:

curl -i -X POST "$API_URL/recommendations/weekly" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"week_start":"<monday-date>"}'
# Allow up to ~30s for Azure OpenAI latency

curl -i "$API_URL/recommendations/latest" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Expected: HTTP 201 (not 502/503). Fake responses use deterministic Spanish; Azure responses vary.

## Rollback to fake provider

```bash
terraform plan -var-file="terraform.postgres.example.tfvars"
# Expected: Container App AI_PROVIDER=fake; Azure OpenAI secrets removed from wiring

terraform apply -var-file="terraform.postgres.example.tfvars"
# Only if rollback is explicitly desired
```

## Important

- No secrets were exposed during this block.
- Bearer tokens and `DATABASE_URL` were not documented.
- Alembic was not re-run.
- No `terraform destroy` was executed.

## Next step

**Block 4.24 — Final Portfolio Release**.

Runbook: [Portfolio Demo](./portfolio-demo.md) | Terraform journal: [infra/terraform/azure/README.md](../infra/terraform/azure/README.md)
