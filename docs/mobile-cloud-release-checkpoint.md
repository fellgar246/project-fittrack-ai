# FitTrack AI — Mobile + Cloud Release Checkpoint

**Release checkpoint:** Block 5.11  
**Environment:** Azure development (not production)  
**Checkpoint date:** 2026-07-17

---

## 1. Executive summary

FitTrack AI is a cloud-native fitness mobile application built with Flutter, FastAPI, and Azure.
It supports authenticated fitness tracking, weekly readiness analysis, Azure OpenAI recommendations,
and private progress-photo uploads using direct Azure Blob Storage transfers secured through
short-lived user-delegation SAS tokens.

The system is **portfolio-grade**, **cloud-native**, and **secure-by-design**, incrementally
implemented and validated in an Azure development environment. It is not presented as a production
SLA-backed release.

**Live API (dev):** `https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io`

For the prior backend-only checkpoint, see [backend-cloud-checkpoint.md](backend-cloud-checkpoint.md).

---

## 2. Release scope

This checkpoint documents work completed in Blocks 5.1–5.10 and packages it for portfolio,
interview, and operational understanding. **No new product features were added in Block 5.11.**

### In scope

| Area | Status |
|------|--------|
| Flutter mobile client (auth, dashboard, measurements, nutrition, workouts, weekly AI, progress photos) | Complete |
| FastAPI backend | Complete |
| Azure Container Apps deployment | Validated |
| Azure PostgreSQL | Validated |
| Azure Blob Storage (progress photos) | Validated |
| Azure Key Vault + Managed Identity | Validated |
| Azure OpenAI recommendations | Validated |
| Terraform modular infrastructure | Clean plan |
| Backend, Flutter, and cloud smoke tests | Passed |

### Out of scope (explicitly not implemented)

Refresh tokens, edit/delete CRUD for most entities, progress photo delete/camera/thumbnails,
workout sessions, CI/CD pipeline, production environment, custom domain, Application Insights,
background jobs, AI vision.

---

## 3. System architecture

```mermaid
flowchart LR
    Mobile[Flutter Mobile App]
    API[FastAPI on Azure Container Apps]
    DB[(Azure PostgreSQL)]
    KV[Azure Key Vault]
    AOAI[Azure OpenAI]
    Blob[Private Azure Blob Storage]
    ACR[Azure Container Registry]
    TF[Terraform]

    Mobile -->|JWT REST API| API
    API --> DB
    API --> KV
    API --> AOAI
    API -->|User delegation SAS| Mobile
    Mobile -->|Direct HTTPS PUT| Blob
    API -->|Validate blob metadata| Blob
    API -->|Short-lived read SAS| Mobile
    ACR --> API
    TF --> API
    TF --> DB
    TF --> KV
    TF --> AOAI
    TF --> Blob
    TF --> ACR
```

**Data flow summary:**

- Mobile talks to FastAPI with JWT bearer tokens for all business logic.
- Progress photos bypass the backend for byte transfer: FastAPI authorizes, mobile PUTs directly to Blob.
- Secrets never ship in the mobile app or Docker image; Key Vault + Managed Identity resolve them at runtime.

---

## 4. Mobile architecture

```mermaid
flowchart LR
    UI[Presentation]
    Controller[Riverpod Controllers]
    Repository[Repositories]
    APIClient[Authenticated Dio API Client]
    BlobClient[Unauthenticated Blob Dio Client]
    Backend[FastAPI]
    Blob[Azure Blob Storage]

    UI --> Controller
    Controller --> Repository
    Repository --> APIClient
    Repository --> BlobClient
    APIClient --> Backend
    BlobClient --> Blob
```

### Design principles

| Principle | Implementation |
|-----------|----------------|
| Feature-first layout | `mobile/lib/features/{auth,dashboard,measurements,nutrition,workouts,weekly_summary,recommendations,progress_photos}/` |
| Immutable state | Freezed/sealed state classes in controllers |
| Controllers without `BuildContext` | Navigation via router callbacks and `ref` |
| API calls outside widgets | Repositories + API classes |
| Separate Blob client | `ProgressPhotoUploadClient` — no JWT interceptors |
| Bearer never sent to Blob | Tested explicitly in unit tests |
| Normalized errors | `ErrorMapper` + typed exceptions |
| Secure storage for JWT only | `flutter_secure_storage`; passwords never persisted |

**Toolchain:** Flutter 3.13.7, Dart 3.1.3, Riverpod, go_router, Dio, flutter_secure_storage, image_picker.

See [flutter-progress-photos.md](flutter-progress-photos.md) for the dual-client pattern in detail.

---

## 5. Backend architecture

```text
routes/     → HTTP boundary, auth deps, status codes
services/   → business logic, readiness, AI orchestration, photo lifecycle
models/     → SQLAlchemy ORM
schemas/    → Pydantic request/response validation
core/       → config, security (JWT, password hashing)
db/         → async engine and session
```

**Stack:** Python 3.11+, FastAPI (async), SQLAlchemy 2.x async, Alembic, PostgreSQL 16, Pydantic v2, Ruff, pytest.

**Provider pattern:**

- `AI_PROVIDER=fake|azure` — `FakeAIProvider` for local/test; `AzureOpenAIProvider` in cloud.
- `PROGRESS_PHOTO_STORAGE_PROVIDER=fake|azure` — fake for tests; Azure user-delegation SAS in cloud.

---

## 6. Azure infrastructure

| Resource | Purpose |
|----------|---------|
| Azure Container Apps | FastAPI runtime (`ca-fittrack-ai-api-dev`) |
| Azure Container Registry | Private image store (`acrfittrackaidevdev01`) |
| User Assigned Managed Identity | ACR pull, Key Vault, Blob RBAC |
| Azure Key Vault | `DATABASE_URL`, `JWT_SECRET_KEY`, Azure OpenAI secrets |
| Azure PostgreSQL Flexible Server | Relational persistence |
| Azure OpenAI | Weekly fitness recommendations (`fittrack-gpt-5-mini`) |
| Azure Storage Account | Private `progress-photos` container |
| Log Analytics | Container Apps logging |
| Terraform | Modular IaC under `infra/terraform/azure/` |

**Cloud runtime configuration:**

- `AI_PROVIDER=azure`
- `PROGRESS_PHOTO_STORAGE_PROVIDER=azure`
- Backend image: `block-5.8-amd64-fix`
- Alembic head: `a8c3b1d92e47`

See [infra/terraform/azure/README.md](../infra/terraform/azure/README.md) and [azure-blob-progress-photos.md](azure-blob-progress-photos.md).

---

## 7. Authentication and security

### Authentication

| Capability | Status |
|------------|--------|
| Register | `POST /auth/register` |
| Login | `POST /auth/login` → JWT |
| Session restoration | Bootstrap + `GET /auth/me` |
| Secure JWT storage | `flutter_secure_storage` |
| Logout | Token cleared locally |
| Protected routes | go_router guards |
| Centralized 401 handling | Dio interceptor → auth reset |

**JWT expiry:** approximately 60 minutes (`access_token_expire_minutes=60`). **No refresh token.**

---

## 8. Feature matrix

| Feature | Backend | Flutter | Cloud | Tests | Smoke |
|---------|---------|---------|-------|-------|-------|
| Authentication | Complete | Complete | Validated | Passed | Passed |
| Dashboard | Complete | Complete | Validated | Passed | Passed |
| Measurements | Complete* | Complete* | Validated | Passed | Passed |
| Nutrition | Complete* | Complete* | Validated | Passed | Passed |
| Workouts | Complete** | Complete** | Validated | Passed | Passed |
| Weekly Summary | Complete | Complete | Validated | Passed | Passed |
| Azure OpenAI Recommendations | Complete | Complete | Validated | Passed | Passed |
| Progress Photos | Complete*** | Complete*** | Validated | Passed | Passed |

\* List and create only; no edit or delete.  
\** Exercise-level logging; no full workout session concept.  
\*** Upload, confirm, gallery, detail, read access; no delete, camera, or thumbnails.

---

## 9. API inventory

All protected routes require `Authorization: Bearer <token>` unless noted.

### Health

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | No | Liveness probe |

### Auth

| Method | Path | Auth | Purpose | Key errors |
|--------|------|------|---------|------------|
| POST | `/auth/register` | No | Create account | 409 duplicate email |
| POST | `/auth/login` | No | Obtain JWT | 401 invalid credentials |
| GET | `/auth/me` | Yes | Current user profile | 401 invalid/expired token |

### Measurements

| Method | Path | Auth | Purpose | Key errors |
|--------|------|------|---------|------------|
| GET | `/measurements` | Yes | List body measurements | — |
| POST | `/measurements` | Yes | Create measurement | 422 validation |
| GET | `/measurements/progress` | Yes | Progress summary | — |

### Nutrition

| Method | Path | Auth | Purpose | Key errors |
|--------|------|------|---------|------------|
| GET | `/nutrition-logs` | Yes | List logs (optional date filters) | — |
| POST | `/nutrition-logs` | Yes | Create log | 409 duplicate date |
| GET | `/nutrition-logs/summary` | Yes | Weekly summary | — |

### Workouts

| Method | Path | Auth | Purpose | Key errors |
|--------|------|------|---------|------------|
| GET | `/workout-plans` | Yes | List plans | — |
| GET | `/workout-plans/{plan_id}` | Yes | Plan detail with days/exercises | 404 |
| POST | `/workout-plans` | Yes | Create plan (backend capability) | — |
| GET | `/workout-logs` | Yes | List logs (`date_from`, `date_to`) | — |
| POST | `/workout-logs` | Yes | Log one exercise execution | 404 exercise not found |
| GET | `/workout-logs/summary` | Yes | Summary for date range | — |

### Weekly summary and recommendations

| Method | Path | Auth | Purpose | Key errors |
|--------|------|------|---------|------------|
| GET | `/weekly-summary` | Yes | Readiness, metrics, missing data | — |
| POST | `/recommendations/weekly` | Yes | Generate AI recommendation | 422 not ready, 409 exists, 503 timeout |
| GET | `/recommendations/latest` | Yes | Latest saved recommendation | 404 none yet |

### Progress photos

| Method | Path | Auth | Purpose | Key errors |
|--------|------|------|---------|------------|
| POST | `/progress-photos/upload-requests` | Yes | Pending metadata + upload SAS | 415 MIME, 413 size |
| POST | `/progress-photos/{photo_id}/confirm` | Yes | Validate blob, mark active | 404, 409 expired/missing blob |
| GET | `/progress-photos` | Yes | Active metadata only (no SAS) | — |
| POST | `/progress-photos/{photo_id}/access` | Yes | Short-lived read SAS | 404 cross-user |

**Constraints:** JPEG/PNG/WebP only; max 5 MiB; SAS TTL 300 seconds.

---

## 10. Data model inventory

| Table | Description |
|-------|-------------|
| `users` | Account identity, hashed password, fitness goal |
| `workout_plans` | User-owned training plans |
| `workout_days` | Days within a plan (1–7) |
| `exercises` | Exercises within a day (sets/reps targets) |
| `workout_logs` | Individual exercise execution records |
| `nutrition_logs` | Daily macro/calorie entries |
| `body_measurements` | Weight, waist, body fat estimates |
| `ai_recommendations` | Persisted weekly AI recommendation text |
| `progress_photos` | Photo metadata linked to Blob storage |

### `progress_photos` details

| Field / rule | Notes |
|--------------|-------|
| Ownership | `user_id` FK; cross-user access returns 404 |
| `blob_name` | Stable identifier; never a signed URL |
| `status` | `pending` → `active` (or `invalid`) |
| No persisted SAS | URLs issued on demand only |
| Confirm idempotency | Re-confirm on active photo returns 200 |
| Orphan risk | `pending` if upload never confirmed |

---

## 11. AI recommendation flow

```mermaid
sequenceDiagram
    participant M as Flutter
    participant A as FastAPI
    participant D as PostgreSQL
    participant O as Azure OpenAI

    M->>A: GET /weekly-summary
    A->>D: Aggregate weekly data
    A-->>M: is_ready, missing_data, metrics
    M->>A: POST /recommendations/weekly
    A->>D: Verify readiness
    A->>O: Structured prompt
    O-->>A: Recommendation text
    A->>D: Persist ai_recommendations
    A-->>M: RecommendationRead
    M->>A: GET /recommendations/latest
    A-->>M: Latest recommendation
```

**Key behaviors:**

- Backend is the source of truth for readiness (`is_ready_for_ai_recommendation`).
- Azure OpenAI is used in cloud; `FakeAIProvider` only for local/test.
- Mobile receive timeout: 60 seconds for generation.
- Double-submit protection in Flutter controller.
- Uncertain timeout state recovered via `GET /recommendations/latest`.
- Not-ready users receive 422 with `missing_data` detail.

---

## 12. Progress photos flow

```mermaid
sequenceDiagram
    participant M as Flutter
    participant A as FastAPI
    participant B as Azure Blob Storage
    participant D as PostgreSQL

    M->>A: POST /progress-photos/upload-requests
    A->>D: Create pending metadata
    A-->>M: photo_id + short-lived upload SAS
    M->>B: PUT image directly, no backend bearer
    B-->>M: Upload success
    M->>A: POST /progress-photos/{id}/confirm
    A->>B: Validate blob metadata
    A->>D: Mark photo active
    A-->>M: Active photo metadata
    M->>A: GET /progress-photos
    A-->>M: Active metadata without SAS
    M->>A: POST /progress-photos/{id}/access
    A-->>M: Short-lived read SAS
    M->>B: GET image
```

**Security properties:**

- Private container; Shared Key disabled; TLS 1.2.
- User-delegation SAS via Managed Identity.
- TTL 300 seconds; `Cache-Control: no-store` on upload.
- In-memory access cache with 30-second renewal window in Flutter.
- Bearer token never sent to Blob (separate Dio client).

See [progress-photos-architecture.md](progress-photos-architecture.md).

---

## 13. Infrastructure as Code

- **Location:** `infra/terraform/azure/`
- **Environment:** `environments/dev/`
- **Modules:** resource_group, acr, monitoring, container_apps_environment, managed_identities, container_apps, key_vault, postgres, blob_storage, azure_openai
- **Rollout:** incremental `create_*` flags
- **State:** committed lock file; tfvars local and gitignored

**Safe plan command:**

```bash
cd infra/terraform/azure/environments/dev
terraform plan \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars" \
  -var-file="terraform.blob-storage.example.tfvars"
```

`terraform.azure-openai.local.tfvars` is local and gitignored. Never apply using only example tfvars when local Azure OpenAI values are required.

---

## 14. Deployment process

### Preflight

1. Confirm working tree clean or intentional changes only.
2. Review open Azure cost / teardown policy ([teardown.md](teardown.md)).

### Backend validation

```bash
cd backend
export DATABASE_URL=postgresql+psycopg://fittrack:fittrack@localhost:5434/fittrack
uv run ruff check .
uv run pytest
uv run alembic upgrade head
```

### Flutter validation

```bash
cd mobile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

### Terraform

```bash
cd infra/terraform/azure/environments/dev
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=...   # review: expect No changes when aligned
```

### Image deploy (when code changed)

```bash
docker build --platform linux/amd64 -t fittrack-api:<tag> backend/
az acr login --name <acr-name>
docker tag fittrack-api:<tag> <acr>.azurecr.io/fittrack-api:<tag>
docker push <acr>.azurecr.io/fittrack-api:<tag>
# Update Terraform container_app_image_tag, then plan + apply
```

### Post-deploy

1. Run Alembic migration against cloud DB if schema changed.
2. Wait for Container App revision ready.
3. `GET /health` → 200.
4. `./backend/scripts/smoke_progress_photos_cloud.sh`
5. `./backend/scripts/smoke_weekly_recommendations_cloud.sh`
6. Final `terraform plan` drift check.
7. Secrets review — no credentials in logs or docs.

**Do not use `-auto-approve` without manual plan review.**

---

## 15. Validation evidence

Block 5.11 re-validation (2026-07-17):

| Check | Result |
|-------|--------|
| Backend `ruff check` | Passed |
| Backend `pytest` | 100/100 passed (local test DB port 5434) |
| Alembic head | `a8c3b1d92e47` |
| Backend `ruff format --check` | 30 legacy files drift (documented, not fixed) |
| Flutter `dart format` | Passed (0 changed) |
| Flutter `analyze` | Clean |
| Flutter `test` | 319 passed, 1 skipped (cloud E2E opt-in) |
| Terraform fmt/validate/plan | Passed / clean |
| Cloud `/health` | HTTP 200 |

Prior cloud smoke evidence: [progress-photos-release-validation.md](progress-photos-release-validation.md).

**Mobile validation note:** No interactive iOS Simulator smoke was performed. The mobile cloud lifecycle was validated through macOS execution and an opt-in automated Flutter cloud integration test.

---

## 16. Test summary

| Layer | Count | Notes |
|-------|-------|-------|
| Backend pytest | 100 | PostgreSQL local test DB; schema reset per test |
| Flutter unit/widget | 319 | No network in regular tests |
| Flutter cloud E2E | 1 (skipped by default) | Opt-in via `RUN_CLOUD_E2E=true` |

### Test providers

- `FakeAIProvider` — deterministic AI responses
- `FakeProgressPhotoStorage` — no Azure in unit tests

### Cloud smoke scripts

| Script | Purpose |
|--------|---------|
| `backend/scripts/smoke_progress_photos_cloud.sh` | Full photo lifecycle in cloud |
| `backend/scripts/smoke_weekly_recommendations_cloud.sh` | Readiness + Azure OpenAI generation |
| `mobile/test/integration/cloud_progress_photos_e2e_test.dart` | Flutter repository + Blob client E2E |

**Cloud E2E opt-in:**

```bash
flutter test test/integration/cloud_progress_photos_e2e_test.dart \
  --dart-define=RUN_CLOUD_E2E=true \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=<api-url>
```

Default `flutter test` skips this test (`bool.fromEnvironment('RUN_CLOUD_E2E', defaultValue: false)`).

---

## 17. Cloud smoke evidence

Summarized from Block 5.10 validation:

### Progress photos

| Step | Result |
|------|--------|
| 401 without auth | Passed |
| 415 invalid MIME | Passed |
| 413 oversized request | Passed |
| Direct Blob PUT | 201 |
| Blob PUT without bearer | Passed |
| Confirm idempotency | Passed |
| List without SAS | Passed |
| Private access | Passed |
| User isolation | 404 |

### Weekly recommendations

| Step | Result |
|------|--------|
| Not-ready user | `is_ready=false`, generate → 422 |
| Ready user | Recommendation generated |
| Azure OpenAI real | Confirmed |
| Persistence | Passed |
| GET latest | Passed |

---

## 18. Security posture

### Implemented

- JWT authentication and ~60-minute expiry
- Secure token storage (mobile)
- Protected routes and centralized 401 handling
- Managed Identity for ACR, Key Vault, Blob
- Key Vault secret references in Container Apps
- Private Blob container; Shared Key disabled; TLS 1.2
- Short-lived user-delegation SAS (upload + read)
- Minimum-privilege RBAC
- Ownership checks; 404 for cross-user photo access
- SAS redaction in logs and errors
- No signed URLs persisted in PostgreSQL
- No storage keys in mobile app
- No bearer sent to Blob (separate Dio client)
- Terraform-managed infrastructure
- Secrets excluded from Git (`.env`, `*.tfvars` gitignored)

### Not claimed

- End-to-end encryption
- HIPAA / SOC 2 compliance
- Penetration testing or formal threat-model certification
- Production SLA / disaster recovery
- Multi-region architecture

---

## 19. Threat model summary

| Risk | Mitigation | Residual risk |
|------|------------|---------------|
| Cross-user photo access | Ownership checks + 404 | Application authorization bugs |
| Public blob exposure | Private container | Configuration drift |
| SAS leakage | Short TTL + redacted logs | Client memory exposure |
| Bearer sent to Blob | Separate Dio client | Regression without tests |
| Oversized upload | 5 MiB precheck + backend validation | Client-side bypass before backend reject |
| Fake MIME | Allowlist + confirm metadata | Limited magic-byte inspection |
| Orphan blob | Pending state | No cleanup scheduler yet |
| Lost confirm after app close | Idempotent confirm | No persistent recovery |
| Secret in repository | gitignore + reviews | Human error |
| Azure role overreach | Scoped RBAC | Misconfiguration |

---

## 20. Cost considerations

**Primary cost drivers (qualitative):**

| Resource | Driver |
|----------|--------|
| PostgreSQL Flexible Server | Uptime tier and storage |
| Container Apps | Replica count and CPU/memory |
| Azure OpenAI | Token usage per recommendation |
| ACR | Stored image layers |
| Log Analytics | Ingestion volume and retention |
| Blob Storage | Capacity and operations |
| Outbound bandwidth | API and Blob transfers |

**Cost control actions:**

- Scale Container Apps to zero when applicable (dev idle periods)
- Remove unused ACR image tags
- Review Log Analytics retention
- Limit Azure OpenAI demo usage
- Tear down resources when portfolio demo is complete ([teardown.md](teardown.md))
- Run `terraform destroy` only when formally closing the environment

No exact monthly figures are documented here; consult Azure Cost Management for live spend.

---

## 21. Known limitations

### Authentication

- No refresh token; session expires in ~60 minutes.

### CRUD

- Measurements: no edit/delete
- Nutrition logs: no edit/delete
- Workout logs: no edit/delete
- Progress photos: no delete

### Workouts

- Logs one exercise per submit; no full workout session concept.

### Progress photos

- Gallery picker only (no camera, crop, compression, thumbnails, comparison)
- No automatic orphan blob cleanup
- No persistent confirm recovery after app restart
- HTTP cache may retain image bytes briefly
- Expired upload SAS requires new upload request (new `photo_id`)

### Mobile validation

- No interactive iOS Simulator smoke; macOS + opt-in cloud E2E used.

### Operations

- CI quality gates for backend, Flutter (Block 6.1), and Terraform static validation (Block 6.2); no full release/deploy pipeline
- No production environment or custom domain
- No alerting or formal SLO/SLA

---

## 22. Technical debt

### High value

- Refresh token / rotation
- Progress-photo orphan cleanup job
- Terraform cloud-backed plan (Block 6.3 — OIDC + remote state)
- Production-grade observability (Application Insights)
- Dedicated staging/production environments

### Medium value

- Edit/delete flows for measurements, nutrition, workouts
- Workout session domain model
- Server-side thumbnails
- Image privacy / cache hardening
- Visual regression tests
- iOS/Android interactive release smoke

### Low priority

- Crop, filters, comparison slider, camera
- AI image analysis

### Formatting drift

`ruff format --check` reports preexisting formatting drift in approximately 30 legacy backend files. Not corrected in Block 5.11 to avoid unrelated mass reformat.

---

## 23. Demo runbook

### Full demo (5–8 minutes)

1. **Architecture** — Show system diagram (Flutter → FastAPI → Azure services → direct Blob).
2. **Login** — Use a disposable demo account (see credentials strategy below).
3. **Dashboard** — Weekly readiness, latest measurement, latest recommendation, quick actions.
4. **Add measurement** — Create entry; show dashboard refresh.
5. **Add nutrition log** — Create entry; note duplicate-date handling if relevant.
6. **Register workout exercise** — Plan → day → exercise → log.
7. **Weekly readiness** — Show missing data or ready state from backend.
8. **Generate recommendation** — Azure OpenAI (may take 20–30s); show persisted result.
9. **Upload progress photo** — Gallery pick, preview, upload, confirm.
10. **Gallery and detail** — On-demand read SAS; explain no bearer on Blob PUT.
11. **Terraform** — Brief modules overview in `infra/terraform/azure/`.
12. **Tests and docs** — Point to 100 backend + 319 Flutter tests and this checkpoint.

Pre-seeded demo data is acceptable; live writes are optional.

### Short demo (2 minutes)

Login → dashboard readiness → show one AI recommendation → open progress photo gallery → explain direct Blob upload architecture → mention Terraform + test coverage.

---

## 24. Demo credentials strategy

**Recommendation:** Generate a temporary demo account before each presentation and remove or rotate it afterward.

| Do | Don't |
|----|-------|
| Create disposable users via register | Commit credentials to Git |
| Use synthetic fitness data | Reuse personal passwords |
| Rotate or delete after demo | Hardcode email/password in README |
| Document the strategy only | Share bearer tokens in slides |

Smoke scripts use placeholder passwords (`DemoPass123!`) for automated testing against dev — treat as non-production only.

---

## 25. How to present FitTrack AI

I built FitTrack AI as a cloud-native mobile fitness platform using Flutter, FastAPI, and Azure.
The project includes authenticated fitness tracking, backend-calculated weekly readiness, persisted
Azure OpenAI recommendations, and private progress-photo storage using direct Blob uploads with
short-lived user-delegation SAS. The infrastructure is managed with Terraform and the system is
covered by backend, Flutter, and cloud integration tests validated in an Azure development
environment.

---

## 26. Interview talking points

### Why Flutter?

Cross-platform from a single codebase; strong typing; Riverpod for testable state; good portfolio
mobility across iOS, Android, and desktop targets.

### Why FastAPI?

Python async stack; Pydantic schemas; auto OpenAI; simple container deployment; excellent for AI
adjacent APIs.

### Why direct Blob upload?

Avoids proxying image bytes through Container Apps; reduces backend load; scales better; pairs with
short-lived SAS and post-upload confirmation.

### Why user-delegation SAS?

Managed Identity eliminates account keys; scoped permissions and expiration enforce least privilege.

### Why confirm after upload?

Validates blob existence, MIME, size, and ownership before marking metadata active.

### Why store blob name instead of URL?

Blob name is stable; SAS URLs are temporary credentials that must not be persisted.

### Why separate Dio clients?

Backend auth (bearer) and Blob auth (SAS query string) are different security contexts; mixing them risks bearer leakage.

### How is readiness calculated?

Backend aggregates weekly measurements, nutrition, and workouts; mobile renders backend `missing_data` without duplicating rules.

### How do you handle AI timeout?

60s mobile timeout; double-submit guard; uncertain state; recovery via `GET /recommendations/latest`.

### What would you improve for production?

Refresh tokens, observability, CI/CD, orphan cleanup, thumbnails, staging/prod environments, alerting, disaster recovery.

---

## Architecture decision records (summary)

| Decision | Chosen approach | Reason |
|----------|-----------------|--------|
| Mobile framework | Flutter | Cross-platform and typed UI |
| State management | Riverpod | Testable controllers and DI |
| Backend | FastAPI | Async API and AI integration |
| Database | PostgreSQL | Relational consistency |
| Cloud runtime | Container Apps | Managed container platform |
| Infrastructure | Terraform | Reproducibility |
| AI provider | Azure OpenAI | Azure-native integration |
| Photo upload | Direct Blob | Avoid backend byte proxy |
| Blob authorization | User-delegation SAS | No account key |
| Photo access | On-demand read SAS | Short-lived private access |
| Storage metadata | PostgreSQL blob name | Stable identifier |
| Test providers | Fake implementations | Deterministic tests |

---

## Repository map

```text
fittrack-ai/
├── backend/           # FastAPI API, Alembic, tests, smoke scripts
│   ├── app/           # routes, services, models, schemas
│   ├── alembic/       # migrations (head: a8c3b1d92e47)
│   ├── scripts/       # cloud smoke scripts
│   └── app/tests/     # 100 pytest tests
├── mobile/            # Flutter client (319 tests + 1 opt-in E2E)
│   ├── lib/features/  # feature-first modules
│   └── test/          # unit, widget, integration tests
├── infra/terraform/   # Azure IaC (modular)
│   └── azure/         # dev environment + modules
└── docs/              # architecture, runbooks, checkpoints
```

---

## Evidence table

| Evidence | Location |
|----------|----------|
| Backend tests | `backend/app/tests/` |
| Flutter tests | `mobile/test/` |
| Photo cloud smoke | `backend/scripts/smoke_progress_photos_cloud.sh` |
| AI cloud smoke | `backend/scripts/smoke_weekly_recommendations_cloud.sh` |
| Flutter cloud E2E | `mobile/test/integration/cloud_progress_photos_e2e_test.dart` |
| Terraform | `infra/terraform/azure/` |
| Photo architecture | `docs/progress-photos-architecture.md` |
| Release validation | `docs/progress-photos-release-validation.md` |
| This checkpoint | `docs/mobile-cloud-release-checkpoint.md` |

---

## Release metadata

| Item | Value |
|------|-------|
| Checkpoint | Block 5.11 — Mobile + Cloud Release Checkpoint |
| Environment | Azure development |
| Backend image | `block-5.8-amd64-fix` |
| Alembic revision | `a8c3b1d92e47` |
| Backend tests | 100 |
| Flutter tests | 319 (+ 1 cloud E2E skipped) |
| Terraform drift | Clean (No changes) |
| Cloud health | HTTP 200 |

**Suggested tag (after commit):** `v0.5.0-mobile-cloud`  
Alternative: `mobile-cloud-checkpoint`

---

## Release status

| Area | Status |
|------|--------|
| Mobile features (5.1–5.9) | Complete |
| Cloud validation (5.10) | Complete |
| Portfolio documentation (5.11) | Complete |
| CI quality gates — backend + Flutter (6.1) | Complete |
| CI quality gates — Terraform static (6.2) | Complete (GitHub run pending commit/push) |
| CI cloud-backed Terraform plan (6.3) | Pending |
| Production readiness | Not claimed |

---

## Recommended next phase

**Block 6.3 — Azure OIDC + Protected Backend Deployment**

Terraform static CI and security checks are implemented in Block 6.2
([docs/terraform-ci-security.md](terraform-ci-security.md)). The next step is Azure OIDC,
remote Terraform state, cloud-backed safe plan, and protected apply — still no unreviewed
deployment.

Observability (Application Insights) remains a parallel high-value track. Alternatives deferred:
production hardening, new product milestone, or portfolio-only maintenance.
