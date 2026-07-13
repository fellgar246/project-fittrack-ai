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
Block 5.5 — Nutrition Logs Flow
Block 5.6 — Workout Flow
Block 5.7 — Weekly Summary + AI Recommendation
Block 5.8 — Progress Photos + Azure Blob Storage
Block 5.9 — Observability Polish
Block 5.10 — Final Portfolio Release
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

## Next block

```text
Block 5.5 — Flutter Nutrition Logs Flow
```
