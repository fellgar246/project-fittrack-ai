# Flutter Measurements Flow

## Purpose

Block 5.4 adds authenticated body measurement tracking to the FitTrack AI Flutter client.
Users can review their measurement history, inspect a backend-owned progress summary, add new
measurements, and refresh the dashboard after recording data.

## Architecture

```text
MeasurementsScreen
→ MeasurementsController
→ MeasurementsRepository
→ MeasurementsApi
→ ApiClient / Dio
→ FastAPI
```

Create flow:

```text
CreateMeasurementScreen
→ CreateMeasurementController
→ MeasurementsRepository
→ MeasurementsApi
```

`MeasurementProgress` lives in the measurements feature and is reused by the dashboard.

## Endpoints

| Operation | Endpoint | Auth | Notes |
|-----------|----------|------|-------|
| List | `GET /measurements` | Bearer | Optional `date_from` / `date_to` (`YYYY-MM-DD`, inclusive). Newest first. Empty → `[]`. |
| Create | `POST /measurements` | Bearer | `201` on success. `409` duplicate date. `422` invalid payload. |
| Progress | `GET /measurements/progress` | Bearer | Same optional date filters. Controlled empty response when no data. |

No detail, edit, or delete endpoints exist.

## Data model

### Create request

| Field | Type | Validation |
|-------|------|------------|
| `date` | date string | Required (`YYYY-MM-DD`) |
| `weight` | number | Required, `> 0` |
| `waist` | number or omitted | Optional, `> 0` when present |
| `body_fat_estimate` | number or omitted | Optional, `1..80` when present |
| `notes` | string or omitted | Optional |

### Read response

| Field | Type |
|-------|------|
| `id` | UUID string |
| `date` | date string |
| `weight` | number |
| `waist` | number or `null` |
| `body_fat_estimate` | number or `null` |
| `notes` | string or `null` |

### Progress response

Backend compares the earliest and latest measurement in the filtered range and returns counts,
endpoint values, and changes. With a single measurement, numeric changes are `0`. With zero
measurements, `measurements_count: 0` and other fields are `null`.

## Units

The API does not encode units in OpenAPI or Pydantic. The mobile UI follows the existing
dashboard convention:

- `weight` → kilograms (`kg`)
- `waist` → centimeters (`cm`)
- `body_fat_estimate` → percent (`%`)

No client-side unit conversion is performed.

## Create flow

```text
Form validation
→ POST /measurements
→ pop to list
→ reload measurements + progress
→ pop(true) to dashboard when leaving after create
→ dashboard refresh()
```

## Error handling

- `401` — reuses auth logout via controller `onUnauthorized`
- `409` — duplicate date per user
- `422` — mapped to `ValidationException` with first field message when available
- Network / timeout / `5xx` — user-friendly `ApiException` messages

List failure is global. Progress failure is localized with retry.

## Security

- Bearer token attached by the shared Dio interceptor
- No measurement data in secure storage
- No credentials or tokens logged by the secure log interceptor

## Limitations

- No edit or delete
- No charts or progress photos
- No offline cache or local database
- No date-range UI filters in this block (API supports optional filters)

## Validation

```bash
cd mobile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Smoke test

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

Use a disposable `example.com` account, create one measurement with reasonable demo values, verify
list/progress/dashboard refresh, then log out.
