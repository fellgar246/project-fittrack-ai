# Flutter Nutrition Logs Flow

## Purpose

Block 5.5 adds authenticated daily nutrition logging to the FitTrack AI Flutter client.
Users can review recent nutrition logs, inspect a backend-owned weekly summary, add new
logs, and refresh the dashboard after recording data.

## Architecture

```text
NutritionScreen
→ NutritionController
→ NutritionRepository
→ NutritionApi
→ ApiClient / Dio
→ FastAPI
```

Create flow:

```text
CreateNutritionLogScreen
→ CreateNutritionLogController
→ NutritionRepository
→ NutritionApi
```

## Endpoints

| Operation | Endpoint | Auth | Notes |
|-----------|----------|------|-------|
| List | `GET /nutrition-logs` | Bearer | Optional inclusive `date_from` / `date_to` (`YYYY-MM-DD`). Newest first. Empty → `[]`. |
| Create | `POST /nutrition-logs` | Bearer | `201` on success. `409` duplicate date per user. `422` invalid payload. |
| Summary | `GET /nutrition-logs/summary` | Bearer | Same optional date filters. Controlled zero-valued response when no data. |

No detail, edit, or delete endpoints exist.

`GET /weekly-summary?week_start=YYYY-MM-DD` remains the dashboard readiness source.
Nutrition summary is feature-specific aggregation; weekly summary drives readiness only.

## Data model

### Create request

| Field | Type | Validation |
|-------|------|------------|
| `date` | date string | Required (`YYYY-MM-DD`) |
| `calories` | integer | Required, `>= 0` |
| `protein` | number | Required, `>= 0` |
| `carbs` | number | Required, `>= 0` |
| `fats` | number | Required, `>= 0` |
| `notes` | string or omitted | Optional |

### Read response

| Field | Type |
|-------|------|
| `id` | UUID string |
| `date` | date string |
| `calories` | integer |
| `protein` | number |
| `carbs` | number |
| `fats` | number |
| `notes` | string or `null` |

### Summary response

| Field | Type |
|-------|------|
| `days_logged` | integer |
| `avg_calories` | number |
| `avg_protein` | number |
| `avg_carbs` | number |
| `avg_fats` | number |
| `total_calories` | integer |
| `total_protein` | number |
| `total_carbs` | number |
| `total_fats` | number |

When no logs match the filter, all values are zero (including averages).

## Units

The API does not encode units in OpenAPI or Pydantic. Backend documentation treats
macros as grams and calories as whole numbers. The mobile UI displays:

- `calories` — plain integer (no `kcal` suffix; not encoded in contract)
- `protein`, `carbs`, `fats` — grams (`g`)

No client-side unit conversion is performed.

## Date ranges

- List: last 30 days via `date_from` only (inclusive), preserving any future-dated logs
  the backend allows.
- Summary: current local Monday–Sunday via `date_from` and `date_to`.

## Create flow

```text
Form validation
→ POST /nutrition-logs
→ pop(true) to list
→ reload logs + weekly summary
→ pop(true) to dashboard when leaving after create
→ dashboard refresh()
```

## Error handling

- `401` — reuses auth logout via controller `onUnauthorized`
- `409` — duplicate date per user (`Nutrition log already exists for this date`)
- `422` — mapped to `ValidationException` with first field message when available
- Network / timeout / `5xx` — user-friendly `ApiException` messages

List failure is global. Summary failure is localized with retry.

## Security

- Bearer token attached by the shared Dio interceptor
- No nutrition data in secure storage
- No credentials or tokens logged by the secure log interceptor

## Limitations

- No edit or delete
- No meal planning, food database, or calorie targets
- No charts or progress photos
- No offline cache or local database
- No date-range UI filters beyond the built-in 30-day list window

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

Use a disposable `example.com` account, create one nutrition log with reasonable demo
values, verify list/summary/dashboard refresh, test duplicate-date `409`, then log out.
