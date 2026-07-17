# Progress Photos Release Validation (Block 5.10)

Execution date: **2026-07-17** (local validation run).

## Objective

Close Blocks 5.8 and 5.9 operationally in cloud and validate the end-to-end flow:

```text
Flutter → FastAPI → Azure Blob Storage → PostgreSQL → gallery → temporary read access
```

Also execute the Block 5.7 interactive cloud smoke (completed in Phase F below).

## Release scope

- No new product features
- Minimal fixes only: `aiohttp` dependency (Block 5.8 cloud), `storage_use_azuread` in Terraform provider (already applied)
- Cloud smoke scripts and Flutter cloud E2E integration test added for repeatable validation

## Git baseline (committed)

Blocks 5.7–5.10 are committed on `main`:

| Commit | Scope |
| --- | --- |
| `d2d1017` | Block 5.7 Flutter weekly/recommendations + Block 5.8 backend progress photos + Terraform blob |
| `7adf8b0` | Block 5.9 Flutter progress photos + Block 5.10 smoke scripts, cloud E2E, validation docs |

Block 5.11 (this checkpoint) adds portfolio documentation only.

## Phase A — Local baseline

| Check | Result |
| --- | --- |
| Backend `ruff check` | Passed |
| Backend `ruff format --check` | Pre-existing drift (30 legacy files); Block 5.8 progress photos files formatted |
| Backend `pytest` (100) | Passed against `localhost:5434` (`fittrack-test-db`) |
| Alembic local head | `a8c3b1d92e47` |
| Flutter tests (319) | Passed |
| Flutter analyze | Clean |
| Flutter macOS build | Passed |

**Note:** Shell `DATABASE_URL` pointed to cloud; local regression used disposable PostgreSQL on port **5434**.

## Phase B — Terraform

| Check | Result |
| --- | --- |
| `terraform fmt -check -recursive` | Passed |
| `terraform validate` | Passed |
| Safe plan (postgres + local OpenAI + blob tfvars) | **No changes**, 0 destroys |
| Azure OpenAI / Key Vault | Preserved (local tfvars used, not example-only) |

## Phase C — Cloud infrastructure

| Resource | Result |
| --- | --- |
| Storage account `stfittrackaidevdev01` | Exists |
| Container `progress-photos` | Private (`publicAccess: null`) |
| Shared key access | Disabled |
| HTTPS only / TLS 1.2 | Enabled |
| RBAC | Storage Blob Delegator + Data Contributor |
| Container App image | `block-5.8-amd64-fix` (revision `--0000005`) |
| Env `PROGRESS_PHOTO_STORAGE_PROVIDER` | `azure` |
| Env `AI_PROVIDER` | `azure` |
| Cloud Alembic | `a8c3b1d92e47 (head)` |
| `/health` | HTTP 200 (cold start ~40s observed once) |

## Phase D — Backend cloud smoke

Script: [`backend/scripts/smoke_progress_photos_cloud.sh`](../backend/scripts/smoke_progress_photos_cloud.sh)

| Step | Result |
| --- | --- |
| Auth absent | 401 |
| Invalid MIME | 415 |
| Oversized metadata | 413 |
| Upload request + SAS | OK (redacted in logs) |
| Direct Blob PUT | 201, no Bearer header |
| Confirm + idempotent replay | 200 / 200 |
| List metadata | 1 photo, no SAS in JSON |
| Read access + GET blob | 200 |
| Private access without SAS | 409 (denied) |
| User isolation | 404 for other user |
| Confirm without PUT | 409, not listed |
| Backend logs | No full SAS / JWT observed in sampled tail |

## Phase E — Flutter smoke

| Check | Result |
| --- | --- |
| Local automated (`test/features/progress_photos/`, 28 tests) | Passed — gallery, upload client (no bearer), retry confirm, SAS redaction |
| Local backend + fake script | Partial — confirm requires simulated blob (documented) |
| Cloud E2E (`test/integration/cloud_progress_photos_e2e_test.dart`) | Passed — full repository lifecycle against cloud API |
| SAS renewal | Cache invalidate + new access URL + successful read |
| Device | macOS desktop (no iOS Simulator available in `flutter devices`) |

Cloud E2E run:

```bash
cd mobile
flutter test test/integration/cloud_progress_photos_e2e_test.dart \
  --dart-define=RUN_CLOUD_E2E=true \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

## Phase F — Block 5.7 cloud smoke

Script: [`backend/scripts/smoke_weekly_recommendations_cloud.sh`](../backend/scripts/smoke_weekly_recommendations_cloud.sh)

| Step | Result |
| --- | --- |
| Not-ready user | `is_ready=false`, missing data listed, generate → 422 |
| Ready user (measurement + 3 nutrition + workout) | `is_ready=true` |
| Azure OpenAI `POST /recommendations/weekly` | 201, non-empty `recommendation` |
| `GET /recommendations/latest` | Persisted |
| Dashboard sync | API-level persistence confirmed; Flutter dashboard covered by existing widget tests |

## Known limitations (unchanged)

- Orphan blobs if app closes after PUT before confirm
- No persistent confirm recovery across app restart
- HTTP image cache may retain bytes after SAS expiry
- No iOS Simulator smoke in this run (macOS + automated cloud E2E used)
- Backend `ruff format --check` pre-existing legacy drift outside Block 5.8/5.9 scope

## Reproducible runbook

```bash
# Backend regression (local DB on 5434)
cd backend
export DATABASE_URL=postgresql+psycopg://fittrack:fittrack@localhost:5434/fittrack
uv run ruff check .
uv run pytest
uv run alembic upgrade head

# Terraform drift check
cd infra/terraform/azure/environments/dev
terraform plan \
  -var-file=terraform.postgres.example.tfvars \
  -var-file=terraform.azure-openai.local.tfvars \
  -var-file=terraform.blob-storage.example.tfvars

# Cloud health
curl https://<container-app-fqdn>/health

# Backend progress photos cloud smoke
./backend/scripts/smoke_progress_photos_cloud.sh

# Block 5.7 cloud smoke
./backend/scripts/smoke_weekly_recommendations_cloud.sh

# Flutter regression + cloud E2E
cd mobile
flutter test
flutter test test/integration/cloud_progress_photos_e2e_test.dart \
  --dart-define=RUN_CLOUD_E2E=true \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://<container-app-fqdn>
```

## Acceptance summary

| Area | Result |
| --- | --- |
| Backend regression | Passed |
| Alembic local | Passed |
| Flutter tests | Passed (319) |
| Flutter analyze | Passed |
| Flutter build | Passed |
| Terraform fmt | Passed |
| Terraform validate | Passed |
| Terraform safe plan | Safe / no changes |
| Terraform apply | Not required (already aligned) |
| Storage private | Passed |
| Shared key disabled | Passed |
| Managed Identity/RBAC | Passed |
| Backend image deploy | Passed (`block-5.8-amd64-fix`) |
| Cloud migration | Passed |
| Cloud health | Passed |
| Upload authorization | Passed |
| Direct Blob PUT | Passed |
| Blob request without bearer | Passed |
| Confirm / idempotency | Passed |
| List / read access | Passed |
| Private access | Passed |
| User isolation | Passed |
| Backend logs review | Passed |
| Flutter local smoke | Passed (automated) |
| Flutter cloud E2E | Passed |
| SAS renewal | Passed |
| Retry confirm | Passed (automated tests) |
| Block 5.7 not-ready | Passed |
| Block 5.7 ready + Azure OpenAI | Passed |
| Recommendation persistence | Passed |
| Terraform final plan | Clean |
| Secrets review | Passed |
| Documentation | Complete |
| **Final acceptance** | **Complete** |

## Suggested commits (historical note)

Blocks 5.7–5.10 were committed as `d2d1017` and `7adf8b0` rather than the originally suggested four-commit split.

## Next step

**Block 5.11 — Mobile + Cloud Release Checkpoint** — complete. See [mobile-cloud-release-checkpoint.md](mobile-cloud-release-checkpoint.md).
