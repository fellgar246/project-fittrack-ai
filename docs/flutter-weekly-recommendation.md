# Flutter weekly summary and AI recommendation (Block 5.7)

## Purpose

Block 5.7 closes the primary FitTrack AI product loop on mobile:

```text
Measurements + Nutrition + Workouts
→ Weekly summary
→ Backend readiness
→ POST /recommendations/weekly
→ Azure OpenAI (via FastAPI)
→ PostgreSQL persistence
→ Flutter display + dashboard sync
```

Flutter never calls Azure OpenAI directly and never computes readiness locally.

## Architecture

```text
WeeklySummaryScreen
→ WeeklySummaryController
→ RecommendationGenerationController
→ WeeklySummaryRepository
→ WeeklySummaryApi
→ Dio
→ FastAPI
→ Azure OpenAI
```

The dashboard reuses the same canonical weekly/recommendation models through
`WeeklySummaryApi` and refreshes explicitly after a successful generation.

## Data flow

1. User opens `/weekly-summary` or `/recommendations` (same integrated screen).
2. `GET /weekly-summary?week_start=YYYY-MM-DD` loads backend aggregates and readiness.
3. `GET /recommendations/latest` loads the persisted recommendation or valid `404` empty state.
4. When `data_quality.is_ready_for_ai_recommendation` is `true`, the user may submit
   `POST /recommendations/weekly` with `{ "week_start": "YYYY-MM-DD" }`.
5. On `201`, the UI shows the persisted recommendation, reloads latest, and refreshes the dashboard.

## Endpoints

| Operation | Method | Path | Request | Success | Notes |
| --- | --- | --- | --- | --- | --- |
| Weekly summary | `GET` | `/weekly-summary` | Query `week_start` | `200` | Includes `data_quality` and `missing_data` |
| Latest recommendation | `GET` | `/recommendations/latest` | Bearer only | `200` / `404` | `404` is valid empty state |
| Generate recommendation | `POST` | `/recommendations/weekly` | `{ "week_start": "YYYY-MM-DD" }` | `201` | Long-running Azure OpenAI call |

Common errors for generation:

| Status | Meaning |
| --- | --- |
| `401` | Invalid/expired session |
| `409` | Recommendation already exists for the week |
| `422` | Not enough weekly data (`detail.message`, `detail.missing_data`) |
| `502` | AI provider failed or invalid output |
| `503` | AI provider unavailable or backend timeout |

## Readiness

Only the backend calculates readiness through `data_quality.is_ready_for_ai_recommendation`
and `missing_data`. Flutter renders those fields and gates the generate button from the API
response only.

## Generation lifecycle

- `idle` — no submission in flight
- `submitting` — `POST /recommendations/weekly` in progress; duplicate taps ignored
- `success` — persisted recommendation applied to the screen
- `failure` — user-visible business/provider error; previous recommendation retained
- `uncertain` — client timeout; user can check latest before retrying

After `409` or client timeout, the app reloads `GET /recommendations/latest` for the requested
week before presenting another generation attempt.

## Timeout strategy

Global Dio timeouts remain `10s / 15s / 30s`. Only `POST /recommendations/weekly` uses a
per-request `receiveTimeout` of **60 seconds** (`recommendationGenerationReceiveTimeout`), leaving
margin above the backend Azure provider timeout and observed ~24s cloud latency.

## Error handling

- Not ready → backend `422` nested message; summary refresh after failure
- `401` → existing auth logout path
- `409` → reload latest for the week
- `502` / `503` → provider-specific user messages
- Client timeout → uncertain state + “Check saved result”

## Security

- No Azure API key, prompts, or provider internals in Flutter
- Bearer token injection remains centralized in Dio
- Recommendations are not cached locally; PostgreSQL/backend is the source of truth

## Limitations

- No recommendation history endpoint
- No streaming, chat, or automatic generation on screen open
- No offline cache
- No direct Azure OpenAI access from mobile

## Validation

```bash
cd mobile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Cloud smoke:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```
