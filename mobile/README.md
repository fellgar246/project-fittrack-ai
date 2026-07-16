# FitTrack AI — Mobile

Flutter mobile client for the FitTrack AI cloud-native fitness platform.

## Overview

This folder contains the FitTrack AI mobile application. Blocks 5.2–5.6 provide real cloud
authentication, a functional fitness dashboard, authenticated measurements flow, nutrition logging,
and workout plan browsing with exercise-level logging backed by the existing API.

**Application ID:** `com.fittrackai.fittrack_ai`

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
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

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

## Testing

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Architecture

```text
lib/
├── app/          # App shell, router, theme
├── core/         # Config, network, errors, storage, validation
├── features/     # Auth, bootstrap, dashboard, measurements, nutrition, workouts
└── shared/       # Reusable widgets
```

## Dependencies

- `flutter_riverpod` — auth and configuration state
- `go_router` — declarative navigation with auth guards
- `dio` — HTTP client
- `flutter_secure_storage` — secure JWT persistence

No new dependencies were added in Block 5.6.

## Current scope

- App foundation
- Theme (light/dark)
- Navigation (`/`, `/login`, `/register`, `/dashboard`, `/measurements`, `/measurements/new`,
  `/nutrition`, `/nutrition/new`, `/workouts`, `/workouts/plans/:planId`, `/workouts/logs/new`,
  `/weekly-summary`, `/recommendations`)
- Environment configuration via `--dart-define`
- Real authentication flow against FastAPI
- Bootstrap session restoration
- Login and register screens
- Functional authenticated dashboard with logout and real API data
- Functional measurements list/create/progress flow with dashboard sync
- Functional nutrition list/create/summary flow with dashboard sync
- Functional workouts list/plan-detail/exercise-log flow with dashboard sync
- Functional weekly summary and AI recommendation flow with dashboard sync
- Unit and widget coverage for auth, dashboard, measurements, nutrition, workouts, and weekly summary layers

## Weekly summary and AI recommendation

- Backend-owned readiness via `data_quality.is_ready_for_ai_recommendation`
- Missing data rendered from `missing_data` without client-side rules
- Latest recommendation with valid `404` empty state
- `POST /recommendations/weekly` with 60s receive timeout for Azure OpenAI latency
- Duplicate-submit guard and uncertain-timeout recovery via latest reload
- Dashboard refresh after successful generation

## Run

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

## Validation

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Current limitations

- No workout plan creation/editing from mobile
- No nutrition or measurement edit/delete
- No set-by-set tracking, timer, or charts
- No recommendation history unless backend adds an endpoint
- No streaming, chat, offline cache, or direct Azure OpenAI access
- No automatic recommendation generation on screen open
- No progress photos
- Azure Blob Storage and mobile observability remain deferred

## Next block

```text
Block 5.8 — Flutter Progress Photos + Azure Blob Storage
```
