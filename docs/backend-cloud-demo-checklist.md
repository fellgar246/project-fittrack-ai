# FitTrack AI — Backend & Cloud Demo Checklist

## Purpose

This checklist supports a 5–10 minute backend/cloud demo of FitTrack AI before the Flutter
mobile phase.

## Before demo

- Confirm Azure resources are running.
- Confirm `/health` returns HTTP 200.
- Confirm Terraform plan is clean or documented.
- Confirm runtime image is `block-4.23-amd64`.
- Confirm no secrets are visible in terminal or docs.
- Prepare terminal with safe commands only.
- Avoid showing `.tfvars`, `.env`, Terraform state or Key Vault values.

## Suggested demo flow

### 1. Project overview — 1 min

- Explain FitTrack AI as a mobile-first fitness platform.
- Clarify that the current checkpoint validates backend/cloud.
- Mention that Flutter mobile is the next phase.

### 2. Architecture — 1 min

- Show README or portfolio architecture diagram.
- Explain FastAPI, PostgreSQL, Azure Container Apps, Key Vault and Azure OpenAI.

### 3. Terraform structure — 1 min

- Show Terraform module structure.
- Explain incremental apply blocks.
- Explain why modules and `create_*` flags were used.

### 4. Azure runtime — 1 min

- Show Container App metadata.
- Show image tag.
- Do not show secrets.

### 5. API validation — 2 min

- Call `/health`.
- Optionally show selected smoke test results from docs.
- Avoid printing tokens.

### 6. AI recommendation flow — 1–2 min

- Explain the Azure OpenAI recommendation flow.
- Mention that Azure OpenAI was validated in Block 4.23.
- Show persisted latest recommendation only if safe.

### 7. Tradeoffs and next steps — 1 min

- Explain current tradeoffs.
- Mention Flutter mobile as next phase.
- Mention Blob Storage and observability as future phases.

## Do not show

- Key Vault secret values
- `DATABASE_URL`
- Azure OpenAI API key
- JWT tokens
- Terraform state files
- `.tfvars` local files
- `.env`
- passwords
- bearer tokens

## Safe commands

```bash
curl -i "https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io/health"
```

```bash
az containerapp show \
  --name "ca-fittrack-ai-api-dev" \
  --resource-group "rg-fittrack-ai-dev" \
  --query "{name:name, provisioningState:properties.provisioningState, latestRevisionName:properties.latestRevisionName, image:properties.template.containers[0].image, fqdn:properties.configuration.ingress.fqdn}" \
  -o json
```

```bash
terraform plan \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars"
```
