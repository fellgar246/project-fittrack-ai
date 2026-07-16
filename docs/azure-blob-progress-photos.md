# Azure Blob Storage for Progress Photos (Block 5.8)

This document describes the Azure resources, RBAC, runtime configuration, and operational notes for FitTrack AI progress photo storage.

## Resources (Terraform)

Module: [`infra/terraform/azure/modules/blob_storage`](../infra/terraform/azure/modules/blob_storage)

| Resource | Purpose |
| --- | --- |
| `azurerm_storage_account` | Private StorageV2 account |
| `azapi_resource` container | Private `progress-photos` container via ARM (no account key) |
| `azurerm_role_assignment` | API managed identity RBAC |

Security defaults:

- HTTPS only
- TLS 1.2 minimum
- `allow_nested_items_to_be_public = false`
- `shared_access_key_enabled = false`
- Public network access enabled (required for native mobile direct upload)
- No CORS (not required for Flutter native clients)

Soft delete: 7 days for blobs and containers (recovery without adding a scheduler).

## RBAC

API user-assigned managed identity receives:

| Role | Scope | Why |
| --- | --- | --- |
| `Storage Blob Delegator` | Storage account | `generateUserDelegationKey` |
| `Storage Blob Data Contributor` | Container | Blob read/create/delete for delegated SAS |

Account keys are not used in cloud runtime.

## Runtime authentication

Cloud backend (`PROGRESS_PHOTO_STORAGE_PROVIDER=azure`):

```text
DefaultAzureCredential
  → Container App user-assigned managed identity
  → user delegation key
  → blob-scoped SAS (create for upload, read for gallery access)
```

Optional `AZURE_CLIENT_ID` selects the API UAMI when multiple identities are attached.

Local/test default:

```text
PROGRESS_PHOTO_STORAGE_PROVIDER=fake
```

Optional manual Azure testing: Azure CLI credential against a dev storage account. Azurite is not required for automated tests.

## Container App environment variables

Non-secret values only:

```text
PROGRESS_PHOTO_STORAGE_PROVIDER=azure
AZURE_STORAGE_ACCOUNT_NAME=<account>
AZURE_STORAGE_CONTAINER_NAME=progress-photos
AZURE_CLIENT_ID=<api-uami-client-id>
PROGRESS_PHOTO_MAX_BYTES=5242880
PROGRESS_PHOTO_UPLOAD_TTL_SECONDS=300
PROGRESS_PHOTO_READ_TTL_SECONDS=300
```

Do not store SAS URLs, account keys, or connection strings in Key Vault for this feature.

## Terraform usage

Enable in dev with cumulative example tfvars:

```bash
cd infra/terraform/azure/environments/dev
terraform init
terraform validate
terraform plan \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.blob-storage.example.tfvars"
```

For environments with real Azure OpenAI values, also pass the ignored local tfvars file documented in the dev README.

Apply only after reviewing the plan. Expect adds for storage account, container, RBAC, and Container App env updates. No unrelated destroys.

## Deployment image tag

After backend changes are validated, publish an immutable amd64 image:

```text
block-5.8-amd64
```

Update `api_image_tag` in Terraform only after the image exists in ACR.

## Cloud smoke (manual)

Use a dedicated smoke user and a small fixture image. Redact SAS output:

```text
https://<account>.blob.core.windows.net/<container>/<blob>?<redacted>
```

Flow:

1. `GET /health`
2. register/login
3. `POST /progress-photos/upload-requests`
4. `PUT` bytes to signed URL
5. `POST /progress-photos/{id}/confirm`
6. `GET /progress-photos`
7. `POST /progress-photos/{id}/access`
8. verify unsigned blob URL returns 403/404
9. verify second user receives `404`

## Local smoke

With fake provider and PostgreSQL:

```bash
cd backend
docker compose up -d db   # or use a local Postgres on another port
uv run alembic upgrade head
PROGRESS_PHOTO_STORAGE_PROVIDER=fake uv run uvicorn app.main:app --reload
./scripts/smoke_progress_photos.sh
```

Automated tests simulate blob upload through `FakeProgressPhotoStorage.simulate_upload`.

## Cost (qualitative)

- Storage account: low baseline cost for infrequent photo uploads
- Egress: direct client ↔ Blob avoids Container Apps egress for image bytes
- RBAC/SAS operations: negligible at portfolio scale

## Limitations

- No CDN, thumbnails, or background cleanup scheduler
- No private endpoint/VNet integration in current CAE
- Confirm trusts blob-declared content type/size, not magic-byte inspection
- Delete endpoint intentionally omitted from Block 5.8
