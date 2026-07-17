# FitTrack AI — Mobile

Flutter mobile client for the FitTrack AI cloud-native fitness platform.

> **Release checkpoint:** [docs/mobile-cloud-release-checkpoint.md](../docs/mobile-cloud-release-checkpoint.md)

## Overview

This folder contains the FitTrack AI mobile application. Blocks 5.2–5.9 provide authenticated
cloud-backed flows: dashboard, measurements, nutrition, workouts, weekly AI recommendations, and
progress photos with direct Blob upload.

**Application ID:** `com.fittrackai.fittrack_ai`
**Tests:** 319 passed (+ 1 cloud E2E opt-in skipped) · **Flutter:** 3.13.7 · **Dart:** 3.1.3

## Requirements

- Flutter SDK 3.13+
- Dart SDK 3.1+
- Xcode for iOS / macOS builds
- Android Studio / Android SDK for Android builds
- CocoaPods for iOS dependencies

## Install

```bash
cd mobile
flutter pub get
```

## Authentication status

- Dio HTTP client with centralized configuration and error mapping
- Secure JWT storage via `flutter_secure_storage`
- Register, login, session restore, `/auth/me`, and logout
- Riverpod auth state and go_router route guards
- Bootstrap session restoration on app start

## Dashboard status

- Authenticated user name and goal from the existing auth state
- Real weekly summary and backend-owned recommendation readiness
- Recent measurement progress with a controlled empty state
- Latest saved AI recommendation; HTTP 404 is treated as a valid empty state
- Parallel requests, global and section-level errors, retry, and pull-to-refresh
- Stable quick-action routes for measurements, nutrition, workouts, weekly summary, and
  recommendations

## Measurements flow

- Protected routes: `/measurements` and `/measurements/new`
- List history, progress summary, empty/error/loading states, pull-to-refresh, and retry
- Create form with backend-aligned validation (`weight`, optional `waist`, `body_fat_estimate`,
  `notes`, `date`)
- Dashboard refresh after a successful create via navigation result + `DashboardController.refresh()`
- Metric display convention: `kg`, `cm`, `%` (not encoded in the API contract)

## Nutrition logs flow

- Protected routes: `/nutrition` and `/nutrition/new`
- List recent logs (last 30 days), weekly nutrition summary, empty/error/loading states,
  pull-to-refresh, and retry
- Create form with backend-aligned validation (`date`, `calories`, `protein`, `carbs`, `fats`,
  optional `notes`)
- Dashboard refresh after a successful create via navigation result + `DashboardController.refresh()`
- Metric display convention: calories as integer; macros in grams (`g`)

## Progress photos flow

- Protected routes: `/progress-photos`, `/progress-photos/new`, `/progress-photos/:photoId`
- Gallery with metadata-only list, on-demand read access URLs, empty/error/loading states,
  pull-to-refresh, and retry
- Create flow: gallery picker, preview, capture date, optional notes, direct blob upload, confirm
- Separate blob upload client (no JWT on PUT to Azure SAS URL)
- In-memory access URL cache with expiry renewal; SAS redaction in logs and errors
- Dashboard quick action entry; gallery refresh after successful create via `pop(true)`

See [docs/flutter-progress-photos.md](../docs/flutter-progress-photos.md).

## Workout flow

- Protected routes: `/workouts`, `/workouts/plans/:planId`, `/workouts/logs/new`
- List workout plans and recent exercise logs (last 30 days), empty/error/loading states,
  pull-to-refresh, and retry
- Plan detail with days, exercises, and target sets/reps (read-only)
- Create form logs one exercise per submit (`exercise_id`, `performed_at`, `sets`, `reps`,
  optional `weight`, optional `notes`) with plan/day/exercise selectors
- Dashboard refresh after a successful create via navigation result + `DashboardController.refresh()`
- Weight displayed as `kg`; `target_reps` shown verbatim from API

## Run against cloud API

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=<api-url>
```

Example dev URL: `https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io`

## Run against local API on iOS Simulator

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Run against local API on Android Emulator

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Security notes

- JWT stored in platform secure storage (`fittrack_access_token`)
- Passwords are never persisted
- Authorization headers and sensitive fields are redacted from development logs
- No refresh token flow (backend does not support refresh tokens)
- **Separate Dio clients:** authenticated API client vs unauthenticated Blob upload client — bearer
  token is never sent to Azure Blob Storage SAS URLs

## Image picker permissions

- **iOS:** Photo library usage description in `ios/Runner/Info.plist`
- **Android:** Photo Picker (no broad storage permissions required)

## Testing

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

**319 tests** run by default. One cloud integration test is **skipped** unless opt-in:

```bash
flutter test test/integration/cloud_progress_photos_e2e_test.dart \
  --dart-define=RUN_CLOUD_E2E=true \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=<api-url>
```

Regular `flutter test` does not require network access.

## Architecture

```text
lib/
├── app/          # App shell, router, theme
├── core/         # Config, network, errors, storage, validation
├── features/     # Auth, bootstrap, dashboard, measurements, nutrition, workouts, progress_photos
└── shared/       # Reusable widgets
```

## Dependencies

- `flutter_riverpod` — auth and configuration state
- `go_router` — declarative navigation with auth guards
- `dio` — HTTP client
- `flutter_secure_storage` — secure JWT persistence
- `image_picker` — gallery image selection (Block 5.9)
- `mime` — content-type detection for uploads (Block 5.9)

## Current scope

- App foundation
- Theme (light/dark)
- Navigation (`/`, `/login`, `/register`, `/dashboard`, `/measurements`, `/measurements/new`,
  `/nutrition`, `/nutrition/new`, `/workouts`, `/workouts/plans/:planId`, `/workouts/logs/new`,
  `/weekly-summary`, `/recommendations`, `/progress-photos`, `/progress-photos/new`,
  `/progress-photos/:photoId`)
- Environment configuration via `--dart-define`
- Real authentication flow against FastAPI
- Bootstrap session restoration
- Login and register screens
- Functional authenticated dashboard with logout and real API data
- Functional measurements list/create/progress flow with dashboard sync
- Functional nutrition list/create/summary flow with dashboard sync
- Functional workouts list/plan-detail/exercise-log flow with dashboard sync
- Functional weekly summary and AI recommendation flow with dashboard sync
- Functional progress photos gallery, upload, and detail flow with dashboard quick action
- Unit and widget coverage for auth, dashboard, measurements, nutrition, workouts, weekly summary,
  and progress photos layers

## Weekly summary and AI recommendation

- Backend-owned readiness via `data_quality.is_ready_for_ai_recommendation`
- Missing data rendered from `missing_data` without client-side rules
- Latest recommendation with valid `404` empty state
- `POST /recommendations/weekly` with 60s receive timeout for Azure OpenAI latency
- Duplicate-submit guard and uncertain-timeout recovery via latest reload
- Dashboard refresh after successful generation

## Current limitations

- No workout plan creation/editing from mobile
- No nutrition or measurement edit/delete
- No set-by-set tracking, timer, or charts
- No recommendation history unless backend adds an endpoint
- No streaming, chat, offline cache, or direct Azure OpenAI access
- No automatic recommendation generation on screen open
- No progress photo delete, edit, camera capture, or before/after comparison
- Progress photos cloud E2E validated (Block 5.10); see [docs/progress-photos-release-validation.md](../docs/progress-photos-release-validation.md)
- Mobile observability remains deferred
