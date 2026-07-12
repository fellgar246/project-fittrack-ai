# Flutter Dashboard

## Purpose

The authenticated dashboard is the mobile entry point for the user's current fitness status. It
combines the backend-owned weekly readiness result, global measurement progress, the latest saved
AI recommendation, and stable navigation entry points without implementing the feature CRUD flows.

## Architecture

```text
DashboardScreen
→ DashboardController
→ DashboardRepository
→ DashboardApi
→ existing ApiClient / Dio
→ FastAPI
```

Riverpod provides the API, repository, and auto-disposed controller. The dashboard reads the
authenticated user from the existing auth state instead of duplicating identity or token state.

## Data sources

| Section | Endpoint | Fields used | Empty behavior |
|---|---|---|---|
| Weekly status | `GET /weekly-summary?week_start=YYYY-MM-DD` | period, workout logs/days, nutrition days, measurement count, readiness, missing data | HTTP 200 controlled summary with zero counts and backend-provided missing data |
| Recent progress | `GET /measurements/progress` | count, end date/weight/waist/body fat, weight change | HTTP 200 with `measurements_count: 0` and nullable values |
| Latest recommendation | `GET /recommendations/latest` | week, summary, recommendation, insights, safety notes | HTTP 404 means no recommendation yet |
| Header | Existing auth state populated by `GET /auth/me` | name, email, goal | Email is the safe display fallback |

There is no latest-measurement endpoint. The dashboard uses the `end_*` fields from the progress
response and does not download the complete measurements list. It never calls
`POST /recommendations/weekly`.

## Loading strategy

- The controller loads once when the authenticated dashboard route creates its auto-disposed
  provider.
- The repository starts all three independent GET requests together.
- Weekly summary is the primary section. Its failure produces the global error view.
- Measurement and recommendation failures are retained as section errors while successful content
  remains visible.
- A 401 from any request triggers the existing auth logout flow and route guard.
- Pull-to-refresh keeps prior data visible. A refresh failure becomes a retryable banner.
- Section retry actions request only the failed optional section.

## Empty states

- No measurements: progress card links to the Block 5.4 placeholder.
- No recommendation: the card explains whether weekly readiness is complete.
- Incomplete readiness: missing categories come directly from backend `missing_data`.

## Security

- Dashboard requests reuse the configured Dio bearer-token interceptor.
- Widgets never read or render the JWT.
- Fitness data is held only in Riverpod memory and is not written to secure storage.
- Development network logs continue to redact authorization and sensitive fields.

## Limitations

- Feature routes are honest placeholders; no measurement, nutrition, or workout CRUD is included.
- No charts, photos, offline cache, or local database.
- Recommendation generation is not initiated from the dashboard.
- The backend does not expose the AI provider in `RecommendationRead`, so the UI labels content
  only as AI-powered and does not claim a provider from response data.
