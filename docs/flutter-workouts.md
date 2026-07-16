# Flutter Workout Flow

## Purpose

Block 5.6 adds authenticated workout plan browsing and exercise-level workout logging to the
FitTrack AI Flutter client. Users can review available plans, inspect plan details with days and
exercises, log completed exercise performance, and refresh the dashboard after recording data.

The backend contract logs **one exercise per request** (`exercise_id`, `performed_at`, `sets`,
`reps`, optional `weight`, optional `notes`). There is no plan-level workout log, duration field,
`completed` flag, or `409` conflict behavior.

## Architecture

```text
WorkoutsScreen
→ WorkoutsController
→ WorkoutsRepository
→ WorkoutsApi
→ ApiClient / Dio
→ FastAPI
```

Plan detail:

```text
WorkoutPlanDetailScreen
→ WorkoutPlanDetailController (family)
→ WorkoutsRepository
→ WorkoutsApi
```

Create flow:

```text
CreateWorkoutLogScreen
→ CreateWorkoutLogController
→ WorkoutsRepository
→ WorkoutsApi
```

## Endpoints

| Operation | Endpoint | Auth | Notes |
|-----------|----------|------|-------|
| List plans | `GET /workout-plans` | Bearer | Returns `WorkoutPlanSummary[]`. Own plans only. Empty → `[]`. |
| Plan detail | `GET /workout-plans/{plan_id}` | Bearer | Nested `days` and `exercises`. `404` if absent or foreign. |
| List logs | `GET /workout-logs` | Bearer | Optional inclusive `date_from` / `date_to` (`YYYY-MM-DD`). Newest first. |
| Create log | `POST /workout-logs` | Bearer | `201` on success. `404` if exercise absent/foreign. `422` invalid payload. |

No plan create/edit/delete, log update/delete, or individual log retrieval endpoints exist in the
mobile scope.

`GET /weekly-summary?week_start=YYYY-MM-DD` remains the dashboard readiness source. Workout logs
affect `workouts.total_logs`, `workouts.workout_days`, `data_quality.has_workout_data`, and
`missing_data` when no logs exist in the selected week.

## Data model

### WorkoutPlanSummary

| Field | Type |
|-------|------|
| `id` | UUID string |
| `name` | string |
| `goal` | string |
| `active` | boolean |
| `days_count` | integer |
| `exercises_count` | integer |

### WorkoutPlanDetail / ExerciseRead

| Field | Type |
|-------|------|
| `days[].day_of_week` | integer (`1`–`7`) |
| `days[].title` | string |
| `days[].exercises[].name` | string |
| `days[].exercises[].muscle_group` | string |
| `days[].exercises[].target_sets` | integer (`> 0`) |
| `days[].exercises[].target_reps` | string |

### Create request (`WorkoutLogCreate`)

| Field | Type | Validation |
|-------|------|------------|
| `exercise_id` | UUID string | Required; must belong to user's plan |
| `performed_at` | ISO date-time | Required |
| `sets` | integer | Required, `> 0` |
| `reps` | integer | Required, `> 0` |
| `weight` | number or omitted | Optional, `>= 0` |
| `notes` | string or omitted | Optional |

### Read response (`WorkoutLogRead`)

| Field | Type |
|-------|------|
| `id` | UUID string |
| `exercise_id` | UUID string |
| `exercise_name` | string (denormalized) |
| `performed_at` | ISO date-time |
| `sets` | integer |
| `reps` | integer |
| `weight` | number or `null` |
| `notes` | string or `null` |

The log response does not include plan or day metadata.

## Units

- `weight` is displayed as kilograms (`kg`) following backend `NUMERIC(6,2)` storage convention.
- `target_reps` is a string in the API (e.g. `"10"`, `"8-12"`); mobile displays it verbatim.
- `sets` and `reps` are integers.

## Date ranges

- Recent logs: last 30 days via `date_from` only (inclusive), matching the nutrition list pattern.
- Dashboard weekly summary: current local Monday–Sunday via existing `DashboardController`.

## Create flow

```text
Select plan → day → exercise
→ form validation (sets, reps, optional weight/notes)
→ POST /workout-logs
→ pop(true)
→ WorkoutsController.reloadAfterCreate()
→ DashboardController.refresh()
→ weekly summary reflects new workout data
```

Exercise selection requires loading plan detail because list summaries do not include exercise IDs.

## Loading and errors

- Plans and logs load in parallel on the workouts screen.
- Plans failure is global; logs failure is localized with retry.
- Pull-to-refresh preserves stale data on temporary failure.
- `401` reuses the existing auth logout path.
- `404` on create indicates exercise not found.
- No `409` handling (backend does not define workout log conflicts).

## Security

- Bearer token injected centrally by Dio; no workout data in secure storage.
- No credentials, tokens, or connection strings in logs or fixtures.

## Validation

```bash
cd mobile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Cloud smoke

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

1. Login with a disposable account.
2. Open Workouts from dashboard quick action.
3. Verify plans load or empty state appears.
4. Open a plan and inspect days/exercises.
5. Log an exercise with sets/reps (and optional weight).
6. Confirm the log appears in recent workouts.
7. Pull-to-refresh on workouts screen.
8. Return to dashboard and verify weekly workout counts/readiness update.
9. Logout.

Plans must exist in the backend for the authenticated user (created via API/workflow, not mobile).

## Limitations

- No plan creation, editing, or deletion from mobile
- No set-by-set tracking, timer, or calories burned
- No offline cache or charts
- One exercise per submit (not a multi-exercise session form)
- Readiness is not recalculated in Flutter; backend owns weekly summary rules

## Next block

```text
Block 5.7 — Flutter Weekly Summary + AI Recommendation
```
