# FitTrack AI — Flutter Mobile Transition

## Decision

The original mobile option was React Native / Expo. The project will now move forward with
Flutter for the mobile client.

## Reason

Flutter was selected to build a polished cross-platform mobile experience and strengthen the
mobile portfolio angle while keeping the existing backend/cloud architecture unchanged.

## What does not change

- FastAPI backend
- PostgreSQL database
- Azure Container Apps deployment
- Azure OpenAI recommendation flow
- Terraform infrastructure
- Docker production image
- Key Vault secret management

## Mobile phase goal

Build a Flutter app that consumes the existing cloud API and demonstrates the end-to-end product
experience.

## Planned mobile blocks

```text
Block 5.1 — Flutter Mobile App Foundation (completed)
Block 5.2 — Flutter API Client + Auth (completed)
Block 5.3 — Mobile Dashboard (completed)
Block 5.4 — Measurements Flow (completed)
Block 5.5 — Nutrition Logs Flow (completed)
Block 5.6 — Workout Flow (completed)
Block 5.7 — Weekly Summary + AI Recommendation
Block 5.8 — Progress Photos Storage Foundation (backend + cloud, completed)
Block 5.9 — Flutter Progress Photos UI (completed)
Block 5.10 — Progress Photos Cloud Deployment + E2E Release Validation (completed)
Block 5.11 — Mobile + Cloud Release Checkpoint (complete)
```

## Block 5.1 — Completed

### Toolchain

- Flutter 3.13.7 (stable)
- Dart 3.1.3

### Architecture

Feature-first layout under `mobile/lib/`:

- `app/` — shell, router, theme
- `core/` — config, constants, errors, API paths
- `features/` — bootstrap, auth, dashboard placeholders
- `shared/` — reusable widgets

### Initial dependencies

- `flutter_riverpod`
- `go_router`

### Environment strategy

Configuration via `--dart-define`:

- `APP_ENV` (`development`, `staging`, `production`)
- `API_BASE_URL` (validated HTTP/HTTPS URL)

### Application identifier

- `com.fittrackai.fittrack_ai`

### Smoke test platform

Validated on macOS desktop (iOS Simulator and Android Emulator available via `flutter doctor`).

### Out of scope in 5.1

- HTTP client
- Auth state
- Secure storage
- Feature flows

## Block 5.2 — Completed

### HTTP and storage

- `dio` 5.4.3+1 — centralized client, timeouts, auth interceptor, error mapping
- `flutter_secure_storage` 9.2.4 — JWT persistence with key `fittrack_access_token`

### Auth strategy

- Register → auto-login → `/auth/me` (backend register returns user only)
- Session restore via stored token + `/auth/me`
- Network errors during restore preserve token and show bootstrap retry
- 401 on `/auth/me` clears token
- No refresh token (backend HS256, 60-minute expiry)

### Navigation guards

- Bootstrap during restore / recoverable failure
- Protected `/dashboard`; public `/login` and `/register`
- Authenticated users skip auth screens

### Testing

- 56 unit and widget tests, no live network in CI tests
- Fakes: `FakeAuthApi`, `FakeAuthRepository`, `InMemoryTokenStorage`

### Smoke test platform

- Cloud API validated via curl against dev Container Apps URL
- macOS desktop available for `flutter run` (no iOS/Android simulator connected in dev env)

### Backend contracts confirmed

- `POST /auth/register` — `{email, name, password, goal}` → user, 201
- `POST /auth/login` — `{email, password}` → `{access_token, token_type}`, 200
- `GET /auth/me` — Bearer → user, 200

### Risks remaining

- JWT expiry requires re-login after ~60 minutes (no refresh endpoint)
- iOS bundle ID differs from documented application ID on Apple targets
- Local HTTP on Android/iOS may need platform-specific cleartext/ATS config (not required for cloud HTTPS)

## Block 5.3 — Implementation complete

### Real dashboard data

- `GET /weekly-summary?week_start=YYYY-MM-DD` — current local Monday through Sunday; primary
  dashboard section
- `GET /measurements/progress` — latest values and simple backend-calculated changes; HTTP 200
  controlled empty response
- `GET /recommendations/latest` — latest persisted recommendation; HTTP 404 mapped to valid absence
- Authenticated identity continues to come from the Block 5.2 auth state

### Models and architecture

- Manual immutable DTOs: `WeeklySummary`, `MeasurementProgress`, `RecommendationSummary`, and
  aggregate `DashboardData`
- `DashboardScreen → DashboardController → DashboardRepository → DashboardApi → ApiClient/Dio`
- Existing bearer interceptor, secure token storage, normalized API errors, and route guards reused
- Auto-disposed Riverpod controller prevents dashboard data from leaking into a later user session

### Loading and errors

- Weekly summary, measurement progress, and recommendation requests start in parallel
- Weekly summary is primary and fails globally
- Optional section failures remain localized and retryable
- Pull-to-refresh preserves stale data if the refresh fails
- Recommendation 404 and zero measurement count render explicit empty states
- No recommendation is generated automatically

### Navigation and scope

- Protected placeholders: `/measurements`, `/nutrition`, `/workouts`, `/weekly-summary`, and
  `/recommendations`
- CRUD forms, charts, offline persistence, and progress photos remain deferred

### Smoke test platform

- Automated tests and static analysis run on macOS.
- The cloud OpenAPI contract was verified against the deployed Azure Container Apps endpoint.
- The macOS Flutter app builds and launches against the cloud URL. Cloud register, login,
  `/auth/me`, and empty dashboard contracts were exercised with ephemeral in-memory credentials.
- Interactive login/dashboard/logout could not be automated because macOS denied assistive access;
  this remains the final acceptance check before marking the block completed.

## MVP mobile scope

The first mobile MVP should include:

- Login
- Register
- Dashboard
- Measurements
- Nutrition logs
- Workout logs
- Weekly summary
- Latest AI recommendation

## Deferred mobile/cloud scope

- Progress photos with Azure Blob Storage
- Push notifications
- Offline mode
- Advanced charts
- App Store / Play Store release
- Full production hardening

## Block 5.4 — Completed

### Measurements endpoints

- `GET /measurements` — authenticated list, newest first, optional inclusive `date_from` /
  `date_to`
- `POST /measurements` — create with `date`, `weight`, optional `waist`, `body_fat_estimate`,
  `notes`; `409` on duplicate user/date
- `GET /measurements/progress` — backend-owned summary and deltas; controlled empty response

### Models and architecture

- `Measurement`, `CreateMeasurementRequest`, `MeasurementProgress`, and `MeasurementsData`
- `MeasurementsScreen → MeasurementsController → MeasurementsRepository → MeasurementsApi`
- `MeasurementProgress` moved to the measurements feature and reused by the dashboard
- Dashboard refresh after create uses navigation result + `DashboardController.refresh()`

### Loading and errors

- List and progress load in parallel
- List failure is global; progress failure is localized with retry
- Pull-to-refresh preserves stale data on temporary failure
- `401` reuses the existing auth logout path

### Units

- Mobile UI displays `weight` as kg, `waist` as cm, and `body_fat_estimate` as %
- Units are a product convention; the API does not encode them in OpenAPI

### Smoke test platform

- Automated tests and static analysis run on macOS (137 tests)
- Cloud OpenAPI and measurement contracts verified against the deployed Azure API
- Interactive app smoke uses a disposable `example.com` account via register/login in the app

### Limitations

- No edit/delete, charts, photos, offline cache, or date-range filters in the UI

## Block 5.5 — Completed

### Nutrition endpoints

- `GET /nutrition-logs` — authenticated list, newest first, optional inclusive `date_from` /
  `date_to`; mobile uses a rolling 30-day `date_from` filter
- `POST /nutrition-logs` — create with `date`, `calories`, `protein`, `carbs`, `fats`, optional
  `notes`; `409` on duplicate user/date
- `GET /nutrition-logs/summary` — backend-owned weekly aggregates; mobile scopes to current
  Monday–Sunday

### Models and architecture

- `NutritionLog`, `CreateNutritionLogRequest`, `NutritionSummary`, and `NutritionData`
- `NutritionScreen → NutritionController → NutritionRepository → NutritionApi`
- Dashboard refresh after create uses navigation result + `DashboardController.refresh()`

### Loading and errors

- List and summary load in parallel
- List failure is global; summary failure is localized with retry
- Pull-to-refresh preserves stale data on temporary failure
- `401` reuses the existing auth logout path

### Units

- Mobile UI displays `calories` as integer; `protein`, `carbs`, `fats` as grams (`g`)
- Units follow backend documentation convention; the API does not encode them in OpenAPI

### Smoke test platform

- Automated tests and static analysis run on macOS (198 tests)
- Cloud OpenAPI and nutrition contracts verified against the deployed Azure API
- Interactive app smoke uses a disposable `example.com` account via register/login in the app

### Limitations

- No edit/delete, meal planning, food database, calorie targets, charts, or offline cache

## Block 5.6 — Completed

### Workout endpoints

- `GET /workout-plans` — authenticated plan summaries (`days_count`, `exercises_count`)
- `GET /workout-plans/{plan_id}` — nested days and exercises with `target_sets` / `target_reps`
- `GET /workout-logs` — authenticated list, newest first, optional inclusive `date_from` /
  `date_to`; mobile uses a rolling 30-day `date_from` filter
- `POST /workout-logs` — exercise-level create with `exercise_id`, `performed_at`, `sets`, `reps`,
  optional `weight`, optional `notes`; `404` if exercise absent/foreign; no `409` conflicts

### Models and architecture

- `WorkoutPlan`, `WorkoutPlanDetail`, `WorkoutLog`, `CreateWorkoutLogRequest`, `WorkoutsData`
- `WorkoutsScreen → WorkoutsController → WorkoutsRepository → WorkoutsApi`
- Plan detail uses `WorkoutPlanDetailController` (family provider)
- Create flow selects plan → day → exercise because logs require `exercise_id`
- Dashboard refresh after create uses navigation result + `DashboardController.refresh()`

### Loading and errors

- Plans and logs load in parallel
- Plans failure is global; logs failure is localized with retry
- Pull-to-refresh preserves stale data on temporary failure
- `401` reuses the existing auth logout path

### Units

- `weight` displayed as `kg`; `target_reps` shown verbatim (string in API)
- `sets` and `reps` are positive integers

### Tests

- 258 automated tests; `flutter analyze` clean
- Cloud OpenAPI verified against deployed Azure API

### Limitations

- No plan create/edit/delete, set-by-set tracking, timer, charts, or offline cache
- One exercise per submit (not atomic multi-exercise sessions)

## Block 5.7 — Flutter Weekly Summary + AI Recommendation — completed

### Scope

- Integrated `/weekly-summary` and `/recommendations` screen
- Canonical weekly summary and recommendation models in `features/weekly_summary`
- `GET /weekly-summary`, `GET /recommendations/latest`, `POST /recommendations/weekly`
- Backend readiness/missing data rendering only
- Generation controller with duplicate-submit guard and 60s receive timeout
- Dashboard sync after successful generation

### Endpoints

| Operation | Path |
| --- | --- |
| Weekly summary | `GET /weekly-summary?week_start=YYYY-MM-DD` |
| Latest recommendation | `GET /recommendations/latest` |
| Generate recommendation | `POST /recommendations/weekly` |

### Tests

- 289 automated tests; `flutter analyze` clean (one informational `prefer_const_constructors` lint)
- Cloud OpenAPI verified against deployed Azure API during planning

### Limitations

- No recommendation history, streaming, chat, offline cache, or automatic generation
- No direct Azure OpenAI access from Flutter

## Block 5.8 — Progress Photos Storage Foundation — completed

Backend, PostgreSQL, Terraform, and Azure Blob Storage foundation for progress photos. No Flutter functional changes in this block.

### Delivered

- Direct upload architecture with user-delegation SAS (not backend proxy)
- API endpoints: upload request, confirm, list, per-photo access
- `progress_photos` table and Alembic migration
- `FakeProgressPhotoStorage` for deterministic tests
- Private storage account + container via Terraform module
- Managed Identity RBAC (`Storage Blob Delegator` + `Storage Blob Data Contributor`)

### API contract for Block 5.9

| Operation | Path |
| --- | --- |
| Create upload authorization | `POST /progress-photos/upload-requests` |
| Confirm upload | `POST /progress-photos/{photo_id}/confirm` |
| List metadata | `GET /progress-photos` |
| Read access URL | `POST /progress-photos/{photo_id}/access` |

See [docs/progress-photos-architecture.md](progress-photos-architecture.md).

## Block 5.9 — Flutter Progress Photos UI — completed

Flutter gallery, upload, confirm, and detail flow on the Block 5.8 API. Cloud E2E validated in Block 5.10.

### Delivered

- Feature module `mobile/lib/features/progress_photos/` (data, application, presentation)
- Gallery picker, preview, capture date, optional notes, client-side MIME/size validation
- Three-step upload: authorization → direct blob PUT → confirm with retry-confirm recovery
- Isolated `ProgressPhotoUploadClient` (no JWT on blob requests)
- In-memory read access cache with expiry renewal
- SAS URL redaction for logs and errors
- Protected routes `/progress-photos`, `/progress-photos/new`, `/progress-photos/:photoId`
- Dashboard quick action entry
- iOS photo library permission; Android Photo Picker without broad storage permissions
- 30 new automated tests (319 total); `flutter analyze` clean; macOS build verified

See [docs/flutter-progress-photos.md](flutter-progress-photos.md).

### Pending for final acceptance

- None for Blocks 5.8–5.10 (see [progress-photos-release-validation.md](progress-photos-release-validation.md))

## Block 5.10 — Progress Photos Cloud Release Validation — completed

Cloud deployment and end-to-end validation for progress photos and Block 5.7 interactive smoke.

### Validated in cloud

- Terraform blob storage aligned (`block-5.8-amd64-fix` image)
- Backend cloud smoke: upload → PUT → confirm → list → access → isolation
- Flutter cloud E2E via integration test (repository + blob client, no bearer on PUT)
- Block 5.7: not-ready / ready users, Azure OpenAI recommendation, persistence

See [progress-photos-release-validation.md](progress-photos-release-validation.md).

## Block 5.11 — Mobile + Cloud Release Checkpoint — completed

Portfolio documentation consolidating Blocks 5.1–5.10. See
[mobile-cloud-release-checkpoint.md](mobile-cloud-release-checkpoint.md).
