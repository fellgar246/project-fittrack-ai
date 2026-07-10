# FitTrack AI — Backend & Cloud Checkpoint

## Checkpoint

Block 4.24 — Backend & Cloud Release Checkpoint

## Summary

FitTrack AI has completed its backend and cloud infrastructure phase. The FastAPI backend is
deployed to Azure Container Apps, pulls a private Docker image from Azure Container Registry,
uses Managed Identity and Key Vault for runtime configuration, persists data in Azure PostgreSQL,
and validates weekly AI-powered recommendations with Azure OpenAI.

This is not the final product release. The next phase is the Flutter mobile application.

## Validated architecture

```text
FastAPI backend
→ Docker production image
→ Azure Container Registry
→ Azure Container Apps
→ Managed Identity
→ Azure Key Vault
→ Azure PostgreSQL Flexible Server
→ Alembic migrations
→ Azure OpenAI recommendations
```

## What works

- FastAPI backend deployed to Azure Container Apps
- Private ACR image pull through Managed Identity + AcrPull
- Runtime secrets through Azure Key Vault
- Azure PostgreSQL persistence
- Alembic schema migrations
- Auth flow in cloud
- Fitness tracking endpoints
- Weekly summary readiness
- Azure OpenAI weekly recommendation flow
- Recommendation persistence in PostgreSQL
- Terraform-managed firewall rule for ACA egress to PostgreSQL

## Validated cloud flows

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- Measurements CRUD/list/progress
- Nutrition logs + summary
- Workout plans + workout logs
- Weekly summary
- `POST /recommendations/weekly` with Azure OpenAI
- `GET /recommendations/latest`

## Final runtime image

```text
acrfittrackaidevdev01.azurecr.io/fittrack-api:block-4.23-amd64
```

## Important tradeoffs

- PostgreSQL networking is currently dev/portfolio-grade with a narrow firewall rule.
- Private networking is deferred.
- Mobile integration is not implemented yet.
- Progress photo storage with Azure Blob Storage is deferred.
- Azure Monitor / Application Insights observability polish is deferred.
- No custom domain.
- No CI/CD release pipeline yet.
- No load testing.

## Next phase

```text
Block 5.1 — Flutter Mobile App Foundation
```
