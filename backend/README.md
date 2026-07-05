# FitTrack AI — Backend

API backend de FitTrack AI. Bloque actual: **5.2 — Azure OpenAI Integration**.

## Stack

- Python 3.11+
- FastAPI (async)
- SQLAlchemy 2.x (async, motor `asyncpg`-style vía `psycopg[binary]` en modo async)
- Alembic (migraciones, template async)
- PostgreSQL 16
- Pydantic v2 / pydantic-settings
- `pwdlib[argon2]` (hashing de passwords) + `PyJWT` (access tokens)
- Docker Compose (entorno local)
- Pytest + pytest-asyncio + httpx (tests)
- uv (gestión de dependencias)
- Ruff (lint)

## Estructura

```text
backend/
  app/
    main.py                # crea la app FastAPI y monta los routers
    api/
      deps.py               # dependency get_current_user (auth por Bearer token)
      routes/                # capa HTTP: health, auth, users, workout_plans, workout_logs, nutrition_logs, measurements, weekly_summary, recommendations
    core/
      config.py              # configuración vía variables de entorno (pydantic-settings)
      security.py             # hashing de passwords y JWT (crear/decodificar)
    db/                     # engine async, sesión, Base declarativa
    models/                 # modelos SQLAlchemy (ORM)
    schemas/                # modelos Pydantic de entrada/salida
    services/               # lógica de negocio (no HTTP, no ORM directo en routes)
    tests/                   # tests con pytest
  alembic/                  # migraciones (template async)
  Dockerfile
  docker-compose.yml
  pyproject.toml
  .env.example
```

**Principio de capas:** `routes` habla con `services`, `services` habla con `models` vía la sesión de `db`. `schemas` valida entrada/salida en el borde HTTP. `core` centraliza configuración y seguridad — nada de secretos hardcodeados.

## Modelo `User`

| Campo           | Tipo      | Notas                                  |
|-----------------|-----------|-----------------------------------------|
| `id`            | UUID      | PK, generado en Python (`uuid.uuid4`)   |
| `email`         | string    | único, indexado                         |
| `name`          | string    |                                          |
| `password_hash` | string    | hash de la password (argon2 vía `pwdlib`); nunca se expone en respuestas |
| `goal`          | string    | default `"body recomposition"`          |
| `created_at`    | datetime  | `server_default=now()`                  |
| `updated_at`    | datetime  | se actualiza automáticamente (`onupdate`) |

## Modelos `WorkoutPlan`, `WorkoutDay`, `Exercise`

Un plan de entrenamiento pertenece a un solo usuario y tiene varios días; cada día
tiene varios ejercicios. Relación 1-N encadenada: `WorkoutPlan → WorkoutDay → Exercise`.

**`workout_plans`**

| Campo        | Tipo      | Notas                                    |
|--------------|-----------|-------------------------------------------|
| `id`         | UUID      | PK                                         |
| `user_id`    | UUID      | FK → `users.id`, indexado                  |
| `name`       | string    |                                             |
| `goal`       | string    |                                             |
| `active`     | boolean   | default `true`                             |
| `created_at` / `updated_at` | datetime | igual que `User`             |

**`workout_days`**

| Campo         | Tipo    | Notas                                  |
|---------------|---------|------------------------------------------|
| `id`          | UUID    | PK                                        |
| `plan_id`     | UUID    | FK → `workout_plans.id`, indexado         |
| `day_of_week` | integer | `1` (lunes) a `7` (domingo)               |
| `title`       | string  |                                            |

**`exercises`**

| Campo            | Tipo    | Notas                                                        |
|------------------|---------|----------------------------------------------------------------|
| `id`             | UUID    | PK                                                              |
| `workout_day_id` | UUID    | FK → `workout_days.id`, indexado                                |
| `name`           | string  |                                                                  |
| `muscle_group`   | string  |                                                                  |
| `target_sets`    | integer | debe ser mayor a `0`                                            |
| `target_reps`    | string  | permite valores no numéricos: `"8-10"`, `"AMRAP"`, `"30 seconds"` |

Al borrar un `WorkoutPlan` se borran en cascada sus días y ejercicios
(`cascade="all, delete-orphan"` en las relaciones de SQLAlchemy).

## Modelo `WorkoutLog`

Un `WorkoutLog` registra el desempeño real de un usuario en un ejercicio específico
(cuántas series, repeticiones y peso usó, y cuándo). A diferencia de `WorkoutPlan`,
no cuelga de un plan sino directamente del usuario — es un hecho histórico de
actividad, no una definición de entrenamiento.

**`workout_logs`**

| Campo          | Tipo      | Notas                                                     |
|----------------|-----------|-------------------------------------------------------------|
| `id`           | UUID      | PK                                                           |
| `user_id`      | UUID      | FK → `users.id`, indexado; siempre `current_user.id`         |
| `exercise_id`  | UUID      | FK → `exercises.id`, indexado; se valida ownership indirecto |
| `performed_at` | datetime  | indexado; permite registrar entrenamientos pasados            |
| `sets`         | integer   | mayor a `0`                                                  |
| `reps`         | integer   | mayor a `0`                                                  |
| `weight`       | numeric(6,2) nullable | `null` para ejercicios con peso corporal          |
| `notes`        | text nullable |                                                            |
| `created_at`   | datetime  | `server_default=now()`                                      |

## Modelo `NutritionLog`

Un `NutritionLog` registra el consumo diario de calorías y macros de un usuario.
A diferencia de `WorkoutLog`, no referencia ningún otro recurso — cuelga
directamente del usuario, sin ownership indirecto que validar.

**`nutrition_logs`**

| Campo        | Tipo          | Notas                                                    |
|--------------|---------------|-------------------------------------------------------------|
| `id`         | UUID          | PK                                                           |
| `user_id`    | UUID          | FK → `users.id`, indexado; siempre `current_user.id`         |
| `date`       | date          | indexado; día al que corresponde el registro                |
| `calories`   | integer       | mayor o igual a `0`                                          |
| `protein`    | numeric(6,2)  | mayor o igual a `0`, admite decimales (ej. `105.5`)          |
| `carbs`      | numeric(6,2)  | mayor o igual a `0`, admite decimales                        |
| `fats`       | numeric(6,2)  | mayor o igual a `0`, admite decimales                        |
| `notes`      | text nullable |                                                               |
| `created_at` / `updated_at` | datetime | igual que `User`                              |

Restricción única: `unique(user_id, date)` — un usuario solo puede tener **un**
`NutritionLog` por día. Intentar crear un segundo log para una fecha ya
registrada devuelve `409 Conflict`.

## Modelo `BodyMeasurement`

Un `BodyMeasurement` registra métricas físicas del usuario (peso, cintura,
estimación de grasa corporal) para un día concreto. Igual que `NutritionLog`,
cuelga directamente del usuario, sin ownership indirecto que validar.

**`body_measurements`**

| Campo               | Tipo          | Notas                                                       |
|---------------------|---------------|-------------------------------------------------------------|
| `id`                | UUID          | PK                                                          |
| `user_id`           | UUID          | FK → `users.id`, indexado; siempre `current_user.id`        |
| `date`              | date          | indexado; día al que corresponde la medición               |
| `weight`            | numeric(6,2)  | requerido, mayor a `0`                                      |
| `waist`             | numeric(6,2)  | opcional; si viene, mayor a `0`                             |
| `body_fat_estimate` | numeric(6,2)  | opcional; si viene, entre `1` y `80`                        |
| `notes`             | text nullable |                                                            |
| `created_at` / `updated_at` | datetime | igual que `User`                                    |

Restricción única: `unique(user_id, date)` — un usuario solo puede tener **una**
medición por día. Intentar crear una segunda medición para una fecha ya
registrada devuelve `409 Conflict`.

## Setup local

Requisitos: Python 3.11+, [uv](https://docs.astral.sh/uv/), Docker + Docker Compose.

```bash
cd backend
uv sync                    # instala dependencias y crea el venv
cp .env.example .env       # variables de entorno locales
```

> Nota: el contenedor de Postgres se expone en `localhost:5433` (no `5432`) para
> no chocar con una instalación local de Postgres, si existiera. El puerto interno
> de la red Docker sigue siendo `5432`.

### Levantar solo la base de datos y correr la API desde el host

```bash
docker compose up -d db
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

### Levantar todo con Docker Compose (db + api)

```bash
docker compose up -d
```

El servicio `api` usa internamente el hostname `db` para conectarse a Postgres
(override de `DATABASE_URL` dentro de `docker-compose.yml`), independientemente
de lo que tenga `.env` para uso desde el host.

## Migraciones (Alembic)

Alembic está configurado en modo async (`alembic init -t async`) y usa el mismo
`Base.metadata` de la app (`alembic/env.py` importa `app.models` y `app.db.base.Base`),
además de tomar la URL de conexión desde `settings.database_url` (no desde `alembic.ini`).

```bash
# Generar una migración a partir de cambios en los modelos
uv run alembic revision --autogenerate -m "descripcion"

# Aplicar migraciones pendientes
uv run alembic upgrade head
```

Las migraciones de estos bloques (`workout_plans`/`workout_days`/`exercises` en 2.3,
`workout_logs` en 2.4, `nutrition_logs` en 2.5, `body_measurements` en 2.6) ya están
generadas y versionadas en `alembic/versions/`; solo hace falta aplicarlas:

```bash
uv run alembic upgrade head
```

Verificar que las tablas existen:

```bash
docker compose exec db psql -U fittrack -d fittrack -c "\dt"
# debe listar: users, workout_plans, workout_days, exercises, workout_logs, nutrition_logs, body_measurements, alembic_version

docker compose exec db psql -U fittrack -d fittrack -c "\d workout_logs"
# debe mostrar columnas, FKs a users/exercises, e índices en user_id, exercise_id y performed_at

docker compose exec db psql -U fittrack -d fittrack -c "\d nutrition_logs"
# debe mostrar columnas, FK a users, índices en user_id y date, y el unique constraint (user_id, date)

docker compose exec db psql -U fittrack -d fittrack -c "\d body_measurements"
# debe mostrar columnas, FK a users, índices en user_id y date, y el unique constraint (user_id, date)
```

Comandos usados para generar la migración de este bloque:

```bash
uv run alembic revision --autogenerate -m "add body measurements table"
uv run alembic upgrade head
```

## Autenticación

El registro y login de usuarios vive bajo `/auth`. El `password_hash` se genera con
`pwdlib[argon2]` y nunca se incluye en ninguna respuesta. El login devuelve un JWT
firmado (HS256) con expiración configurable; ese token se envía como
`Authorization: Bearer <token>` en rutas protegidas.

| Endpoint            | Descripción                                              |
|---------------------|-----------------------------------------------------------|
| `POST /auth/register` | Crea un usuario nuevo. `409 Conflict` si el email ya existe. |
| `POST /auth/login`    | Verifica credenciales y devuelve `{"access_token", "token_type"}`. `401 Unauthorized` si son inválidas. |
| `GET /auth/me`        | Devuelve el usuario autenticado a partir del Bearer token. `401 Unauthorized` sin token, con token inválido/expirado, o si el usuario ya no existe. |

La dependency `get_current_user` (en `app/api/deps.py`) es el punto de entrada que
usarán las rutas protegidas de los próximos módulos (workouts, nutrition,
measurements, AI recommendations) para obtener el usuario autenticado — nunca a
partir de un `user_id` recibido del cliente.

## Workout Plans

Todas las rutas de `/workout-plans` requieren `Authorization: Bearer <access_token>`
y operan exclusivamente sobre los planes del usuario autenticado. El cliente nunca
envía `user_id`: se obtiene siempre de `current_user.id` (vía `get_current_user`).

| Endpoint                       | Descripción                                                                 |
|---------------------------------|-------------------------------------------------------------------------------|
| `POST /workout-plans`           | Crea un plan con sus días y ejercicios en una sola transacción. `401` sin token, `422` si el payload es inválido. |
| `GET /workout-plans`            | Lista los planes del usuario autenticado (resumen, sin días/ejercicios anidados). |
| `GET /workout-plans/{plan_id}`  | Devuelve el detalle de un plan con sus días y ejercicios anidados. `404` si no existe o pertenece a otro usuario. |

### `POST /workout-plans` — request

```json
{
  "name": "4-Day Body Recomposition Plan",
  "goal": "body recomposition",
  "active": true,
  "days": [
    {
      "day_of_week": 1,
      "title": "Upper Body",
      "exercises": [
        {
          "name": "Pull-ups",
          "muscle_group": "back",
          "target_sets": 4,
          "target_reps": "6-8"
        }
      ]
    }
  ]
}
```

### `POST /workout-plans` / `GET /workout-plans` — response (resumen)

```json
{
  "id": "uuid",
  "name": "4-Day Body Recomposition Plan",
  "goal": "body recomposition",
  "active": true,
  "days_count": 2,
  "exercises_count": 3
}
```

### `GET /workout-plans/{plan_id}` — response (detalle)

```json
{
  "id": "uuid",
  "name": "4-Day Body Recomposition Plan",
  "goal": "body recomposition",
  "active": true,
  "days": [
    {
      "id": "uuid",
      "day_of_week": 1,
      "title": "Upper Body",
      "exercises": [
        {
          "id": "uuid",
          "name": "Pull-ups",
          "muscle_group": "back",
          "target_sets": 4,
          "target_reps": "6-8"
        }
      ]
    }
  ]
}
```

### Validaciones (Pydantic)

- `name`, `goal`, `title`, `exercise.name` requeridos.
- `day_of_week` entre `1` y `7`.
- `target_sets` mayor a `0`.
- `target_reps` requerido (string, no numérico, para admitir `"AMRAP"`, `"30 seconds"`, etc.).

Payload inválido devuelve `422 Unprocessable Entity`.

## Workout Logs

Todas las rutas de `/workout-logs` requieren `Authorization: Bearer <access_token>`
y operan exclusivamente sobre los logs del usuario autenticado. El cliente nunca
envía `user_id`. El `exercise_id` sí lo envía el cliente, pero se valida que
pertenezca a un plan del usuario autenticado (`Exercise → WorkoutDay → WorkoutPlan
→ user_id`); si no, `404 Exercise not found`.

| Endpoint                     | Descripción                                                                 |
|-------------------------------|-------------------------------------------------------------------------------|
| `POST /workout-logs`          | Registra un log de entrenamiento. `401` sin token, `404` si el ejercicio no existe o es de otro usuario, `422` si el payload es inválido. |
| `GET /workout-logs`           | Lista los logs del usuario autenticado, más recientes primero. Acepta `date_from`/`date_to` opcionales (`YYYY-MM-DD`, rango inclusivo). |
| `GET /workout-logs/summary`   | Devuelve agregados básicos sobre los logs filtrados por el mismo rango de fechas. |

### `POST /workout-logs` — request

```json
{
  "exercise_id": "uuid",
  "performed_at": "2026-07-03T18:30:00",
  "sets": 4,
  "reps": 8,
  "weight": 12.5,
  "notes": "Felt strong, good control on last set."
}
```

### `POST /workout-logs` / `GET /workout-logs` — response

```json
{
  "id": "uuid",
  "exercise_id": "uuid",
  "exercise_name": "Pull-ups",
  "performed_at": "2026-07-03T18:30:00",
  "sets": 4,
  "reps": 8,
  "weight": 12.5,
  "notes": "Felt strong, good control on last set."
}
```

`GET /workout-logs` devuelve una lista de objetos con esta misma forma.

### `GET /workout-logs/summary` — response

```json
{
  "total_logs": 4,
  "total_sets": 16,
  "total_reps": 128,
  "unique_exercises": 3,
  "workout_days": 2
}
```

### Validaciones (Pydantic)

- `exercise_id` y `performed_at` requeridos.
- `sets` y `reps` mayores a `0`.
- `weight` opcional; si viene, mayor o igual a `0`.
- `notes` opcional.

## Nutrition Logs

Todas las rutas de `/nutrition-logs` requieren `Authorization: Bearer <access_token>`
y operan exclusivamente sobre los logs del usuario autenticado. El cliente nunca
envía `user_id`. A diferencia de `/workout-logs`, no hay ningún recurso externo que
validar (`NutritionLog` cuelga directamente del usuario), pero sí una restricción de
unicidad: un usuario solo puede tener un log por `date`.

| Endpoint                        | Descripción                                                                 |
|-----------------------------------|-------------------------------------------------------------------------------|
| `POST /nutrition-logs`            | Registra el consumo diario. `401` sin token, `409` si ya existe un log para esa fecha, `422` si el payload es inválido. |
| `GET /nutrition-logs`             | Lista los logs del usuario autenticado, más recientes primero. Acepta `date_from`/`date_to` opcionales (`YYYY-MM-DD`, rango inclusivo). |
| `GET /nutrition-logs/summary`     | Devuelve promedios y totales sobre los logs filtrados por el mismo rango de fechas. |

### `POST /nutrition-logs` — request

```json
{
  "date": "2026-07-03",
  "calories": 1850,
  "protein": 105.5,
  "carbs": 210,
  "fats": 55,
  "notes": "Good protein intake, slightly low calories."
}
```

### `POST /nutrition-logs` / `GET /nutrition-logs` — response

```json
{
  "id": "uuid",
  "date": "2026-07-03",
  "calories": 1850,
  "protein": 105.5,
  "carbs": 210,
  "fats": 55,
  "notes": "Good protein intake, slightly low calories."
}
```

`GET /nutrition-logs` devuelve una lista de objetos con esta misma forma.

Log duplicado para la misma fecha:

```text
409 Nutrition log already exists for this date
```

### `GET /nutrition-logs/summary` — response

```json
{
  "days_logged": 5,
  "avg_calories": 1840,
  "avg_protein": 102.5,
  "avg_carbs": 205.2,
  "avg_fats": 54.8,
  "total_calories": 9200,
  "total_protein": 512.5,
  "total_carbs": 1026,
  "total_fats": 274
}
```

### Validaciones (Pydantic)

- `date` requerido.
- `calories`, `protein`, `carbs`, `fats` mayores o iguales a `0`.
- `notes` opcional.

## Body Measurements

Todas las rutas de `/measurements` requieren `Authorization: Bearer <access_token>`
y operan exclusivamente sobre las mediciones del usuario autenticado. El cliente
nunca envía `user_id`. Igual que `NutritionLog`, `BodyMeasurement` cuelga directamente
del usuario y aplica una restricción de unicidad: un usuario solo puede tener una
medición por `date`.

| Endpoint                      | Descripción                                                                 |
|-------------------------------|-------------------------------------------------------------------------------|
| `POST /measurements`          | Registra una medición corporal. `401` sin token, `409` si ya existe una medición para esa fecha, `422` si el payload es inválido. |
| `GET /measurements`           | Lista las mediciones del usuario autenticado, más recientes primero. Acepta `date_from`/`date_to` opcionales (`YYYY-MM-DD`, rango inclusivo). |
| `GET /measurements/progress`  | Compara la primera y la última medición del rango filtrado y devuelve los cambios de peso, cintura y grasa corporal. |

### `POST /measurements` — request

```json
{
  "date": "2026-07-03",
  "weight": 70.2,
  "waist": 82.5,
  "body_fat_estimate": 24.5,
  "notes": "Morning measurement after cardio day."
}
```

### `POST /measurements` / `GET /measurements` — response

```json
{
  "id": "uuid",
  "date": "2026-07-03",
  "weight": 70.2,
  "waist": 82.5,
  "body_fat_estimate": 24.5,
  "notes": "Morning measurement after cardio day."
}
```

`GET /measurements` devuelve una lista de objetos con esta misma forma.

Medición duplicada para la misma fecha:

```text
409 Body measurement already exists for this date
```

### `GET /measurements/progress` — response

```json
{
  "measurements_count": 4,
  "start_date": "2026-07-01",
  "end_date": "2026-07-31",
  "start_weight": 71.0,
  "end_weight": 70.2,
  "weight_change": -0.8,
  "start_waist": 83.2,
  "end_waist": 82.5,
  "waist_change": -0.7,
  "start_body_fat_estimate": 25.0,
  "end_body_fat_estimate": 24.5,
  "body_fat_change": -0.5
}
```

El progreso compara la **primera** y la **última** medición dentro del rango. Si
solo hay una medición, los cambios son `0`. Si `waist` o `body_fat_estimate` falta
en alguno de los dos extremos, su cambio se devuelve como `null`. Sin mediciones en
el rango, la respuesta es controlada (`measurements_count: 0` y el resto `null`):

```json
{
  "measurements_count": 0,
  "start_date": null,
  "end_date": null,
  "start_weight": null,
  "end_weight": null,
  "weight_change": null,
  "start_waist": null,
  "end_waist": null,
  "waist_change": null,
  "start_body_fat_estimate": null,
  "end_body_fat_estimate": null,
  "body_fat_change": null
}
```

### Validaciones (Pydantic)

- `date` requerido.
- `weight` requerido, mayor a `0`.
- `waist` opcional; si viene, mayor a `0`.
- `body_fat_estimate` opcional; si viene, entre `1` y `80`.
- `notes` opcional.

## Weekly Summary

`GET /weekly-summary` requiere `Authorization: Bearer <access_token>` y consolida,
en una sola respuesta, los datos de `workout_logs`, `nutrition_logs` y
`body_measurements` para una semana del usuario autenticado. No crea tablas
nuevas: orquesta los servicios (`get_summary` / `get_progress`) que ya existen
para cada dominio. Todavía **no llama a ningún modelo de IA** — solo prepara la
capa de datos consolidada.

| Endpoint                          | Descripción                                                                 |
|------------------------------------|-------------------------------------------------------------------------------|
| `GET /weekly-summary?week_start=YYYY-MM-DD` | Consolida workouts, nutrición y mediciones de la semana `[week_start, week_start + 6 días]`. `401` sin token, `422` si falta `week_start` o el formato es inválido. |

### `GET /weekly-summary?week_start=2026-07-01` — response

```json
{
  "user": { "id": "uuid", "name": "Felipe Garcia", "goal": "body recomposition" },
  "period": { "week_start": "2026-07-01", "week_end": "2026-07-07" },
  "workouts": {
    "total_logs": 4,
    "total_sets": 16,
    "total_reps": 128,
    "unique_exercises": 3,
    "workout_days": 2
  },
  "nutrition": {
    "days_logged": 5,
    "avg_calories": 1840,
    "avg_protein": 102.5,
    "avg_carbs": 205.2,
    "avg_fats": 54.8,
    "total_calories": 9200,
    "total_protein": 512.5,
    "total_carbs": 1026,
    "total_fats": 274
  },
  "measurements": {
    "measurements_count": 2,
    "start_date": "2026-07-01",
    "end_date": "2026-07-07",
    "start_weight": 71.0,
    "end_weight": 70.2,
    "weight_change": -0.8,
    "start_waist": 83.2,
    "end_waist": 82.5,
    "waist_change": -0.7,
    "start_body_fat_estimate": 25.0,
    "end_body_fat_estimate": 24.5,
    "body_fat_change": -0.5
  },
  "data_quality": {
    "has_workout_data": true,
    "has_nutrition_data": true,
    "has_measurement_data": true,
    "nutrition_days_logged": 5,
    "measurement_entries": 2,
    "is_ready_for_ai_recommendation": true,
    "missing_data": []
  }
}
```

Sin datos en la semana, la respuesta es controlada (no falla): agregados en `0`,
promedios/deltas en `null`, y `data_quality.missing_data` lista los dominios
faltantes:

```json
{
  "user": { "id": "uuid", "name": "Felipe Garcia", "goal": "body recomposition" },
  "period": { "week_start": "2026-07-01", "week_end": "2026-07-07" },
  "workouts": { "total_logs": 0, "total_sets": 0, "total_reps": 0, "unique_exercises": 0, "workout_days": 0 },
  "nutrition": {
    "days_logged": 0,
    "avg_calories": null,
    "avg_protein": null,
    "avg_carbs": null,
    "avg_fats": null,
    "total_calories": 0,
    "total_protein": 0,
    "total_carbs": 0,
    "total_fats": 0
  },
  "measurements": {
    "measurements_count": 0,
    "start_date": null,
    "end_date": null,
    "start_weight": null,
    "end_weight": null,
    "weight_change": null,
    "start_waist": null,
    "end_waist": null,
    "waist_change": null,
    "start_body_fat_estimate": null,
    "end_body_fat_estimate": null,
    "body_fat_change": null
  },
  "data_quality": {
    "has_workout_data": false,
    "has_nutrition_data": false,
    "has_measurement_data": false,
    "nutrition_days_logged": 0,
    "measurement_entries": 0,
    "is_ready_for_ai_recommendation": false,
    "missing_data": ["workout_logs", "nutrition_logs", "body_measurements"]
  }
}
```

### Regla de `is_ready_for_ai_recommendation`

```text
is_ready_for_ai_recommendation = true cuando:
- hay al menos 1 workout log en la semana
- hay al menos 3 nutrition logs en la semana
- hay al menos 1 body measurement en la semana
```

Si no se cumple alguna condición, es `false` y el dominio correspondiente aparece
en `missing_data` (`"workout_logs"`, `"nutrition_logs"`, `"body_measurements"`).

### Validaciones

- `week_start` requerido y debe ser una fecha válida (`YYYY-MM-DD`); si falta o
  el formato es inválido, FastAPI devuelve `422`.
- `week_end` siempre se calcula en backend como `week_start + 6 días`; no se
  acepta como parámetro.
- El cliente nunca envía `user_id`; se usa siempre `current_user.id`.

## AI Weekly Recommendations (Bloque 5.1)

Primer módulo de **IA aplicada** de FitTrack AI. Toma el weekly summary
consolidado como input, genera una recomendación fitness segura y la persiste.
La generación está aislada detrás de un `AIProvider` con dos implementaciones:
`FakeAIProvider` (default, determinista, sin credenciales) y `AzureOpenAIProvider`
(integración real con Azure OpenAI, ver [Bloque 5.2](#ai-provider-azure-openai-bloque-52)
más abajo). El flujo local y los tests siguen siendo 100% deterministas y no
dependen de credenciales ni de internet.

### Modelo `AIRecommendation`

| Campo            | Tipo      | Notas                                                        |
|------------------|-----------|--------------------------------------------------------------|
| `id`             | UUID      | PK, generado en Python (`uuid.uuid4`)                        |
| `user_id`        | UUID      | FK → `users.id`, indexado                                    |
| `week_start`     | date      | indexado; enviado por el cliente                             |
| `week_end`       | date      | calculado en backend (`week_start + 6 días`)                 |
| `summary`        | text      | resumen en lenguaje natural de la semana                     |
| `insights`       | jsonb     | lista de observaciones (`list[str]`)                         |
| `recommendation` | text      | recomendación práctica de hábitos                            |
| `safety_notes`   | text/null | nota de seguridad; siempre poblada aunque el provider la omita |
| `created_at`     | datetime  | `server_default=now()`                                       |

Restricción única: `unique(user_id, week_start, week_end)` (`uq_ai_recommendations_user_week`)
— evita recomendaciones duplicadas para la misma semana.

### `POST /recommendations/weekly` — request

```json
{
  "week_start": "2026-07-01"
}
```

- Protegido con Bearer token. El cliente **solo** envía `week_start`.
- `week_end` se calcula en backend; `user_id` sale de `current_user.id`.
- El backend consulta internamente el weekly summary y valida
  `data_quality.is_ready_for_ai_recommendation` antes de llamar a la IA.

### `POST /recommendations/weekly` — response (`201`)

```json
{
  "id": "a3f1c2d4-....",
  "week_start": "2026-07-01",
  "week_end": "2026-07-07",
  "summary": "Completaste 1 registros de entrenamiento en 1 día(s) y registraste nutrición 3 día(s).",
  "insights": [
    "Tu consistencia de entrenamiento fue moderada durante la semana.",
    "La proteína estuvo registrada durante suficientes días para detectar una tendencia."
  ],
  "recommendation": "Mantén tus calorías similares durante una semana más, prioriza llegar a tu proteína diaria y conserva la estructura actual de entrenamiento.",
  "safety_notes": "This recommendation is for general fitness habit tracking only and does not replace medical advice."
}
```

### `GET /recommendations/latest` — response

Devuelve la última recomendación del usuario autenticado (por `week_start`
descendente, desempatando por `created_at`), con la misma forma que el `POST`.
Si el usuario no tiene ninguna recomendación → `404 Recommendation not found`.

### Regla de data readiness

Antes de generar, el servicio consulta el weekly summary y exige
`data_quality.is_ready_for_ai_recommendation == true` (≥1 workout log, ≥3
nutrition logs, ≥1 body measurement en la semana). Si no se cumple, devuelve
`422` con el detalle de qué falta:

```json
{
  "detail": {
    "message": "Not enough weekly data to generate recommendation",
    "missing_data": ["workout_logs", "body_measurements"]
  }
}
```

### Seguridad de IA

La recomendación se limita a observaciones **generales** de fitness y hábitos.
El prompt (en `services/ai_provider.py`) instruye explícitamente a la IA a **no**
dar diagnósticos ni consejos médicos/clínicos, no prometer pérdida de peso, no
recomendar cambios extremos de calorías, suplementos ni medicación, no hacer
comentarios negativos sobre el cuerpo, y a usar **solo** los datos entregados sin
inventar información. Toda recomendación incluye además una `safety_notes`
garantizada en backend:

```text
This recommendation is for general fitness habit tracking only and does not replace medical advice.
```

### Variables de entorno del AI provider

```env
AI_PROVIDER=fake          # fake (default) | azure
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_API_KEY=
AZURE_OPENAI_DEPLOYMENT=
AZURE_OPENAI_API_VERSION=
AZURE_OPENAI_TIMEOUT_SECONDS=20   # opcional, default 20
AZURE_OPENAI_MAX_RETRIES=2        # opcional, default 2
```

El provider `fake` funciona sin ninguna de estas variables. El provider `azure`
implementa la llamada real a Azure OpenAI — ver la siguiente sección.

### Validaciones

- `week_start` requerido y válido (`YYYY-MM-DD`); si falta o el formato es
  inválido → `422`.
- No se acepta `week_end` ni `user_id` desde el cliente.
- Datos insuficientes → `422` (con `missing_data`).
- Recomendación ya existente para esa semana → `409 Recommendation already exists for this week`.
- Si el AI provider devuelve JSON inválido o no parseable, se maneja de forma
  controlada → `502 AI provider returned an invalid response`.

## AI Provider: Azure OpenAI (Bloque 5.2)

Implementa la integración real con **Azure OpenAI** dentro de
`AzureOpenAIProvider.generate` (`app/services/ai_provider.py`), usando el SDK
oficial `openai` (`AsyncAzureOpenAI`). `FakeAIProvider` sigue siendo el default
para desarrollo local y tests.

### Fake vs Azure

| | `AI_PROVIDER=fake` (default) | `AI_PROVIDER=azure` |
|---|---|---|
| Credenciales | No requiere ninguna | Requiere las 4 variables `AZURE_OPENAI_*` |
| Llamadas de red | Ninguna | HTTP a Azure OpenAI |
| Determinismo | Total (reglas locales) | Depende del modelo |
| Uso | Local, tests, CI | Manual / cloud |

### Cómo funciona `AzureOpenAIProvider.generate`

1. Construye el prompt seguro con `build_prompt(summary)` (mismas reglas de
   seguridad descritas en [Seguridad de IA](#seguridad-de-ia)).
2. Crea (o reutiliza, si se inyectó en el constructor) un cliente
   `AsyncAzureOpenAI` con `azure_endpoint`, `api_key`, `api_version`, y los
   timeouts/retries configurados.
3. Llama a `client.chat.completions.create(...)` usando el `deployment`
   configurado como `model`, y `response_format={"type": "json_object"}` para
   pedir explícitamente una respuesta JSON.
4. Devuelve el string JSON crudo; la validación con `AIGeneratedContent` y la
   persistencia ocurren en `recommendation_service.py`, igual que con el fake.

La validación de configuración (`AZURE_OPENAI_*` completas) ocurre de forma
**perezosa**, dentro de `generate`, no en el constructor — así el error queda
dentro del `try/except` de la ruta y se traduce en una respuesta HTTP
controlada en vez de un `500` sin manejar.

### Manejo de errores

| Situación                        | Excepción                      | HTTP | Detail                                       |
|-----------------------------------|---------------------------------|------|-----------------------------------------------|
| Falta configuración de Azure      | `AIProviderNotConfiguredError`  | 503  | `AI provider is not configured`               |
| Timeout de Azure OpenAI            | `AIProviderTimeoutError`        | 503  | `AI provider timeout`                         |
| Error de API/SDK de Azure          | `AIProviderError`               | 502  | `AI provider failed`                          |
| Respuesta JSON inválida o vacía    | `InvalidAIResponseError`        | 502  | `AI provider returned an invalid response`    |

Ningún detalle interno del SDK (mensajes de `openai.OpenAIError`, headers,
request ids) se expone al cliente. Nunca se loggean secretos ni el contenido
completo del prompt del usuario.

### Probar en modo fake (sin credenciales)

```bash
export AI_PROVIDER=fake
uv run uvicorn app.main:app --reload
```

Sigue el mismo flujo de curl de la sección anterior — no requiere ningún
`AZURE_OPENAI_*`.

### Probar con Azure OpenAI real

```bash
export AI_PROVIDER=azure
export AZURE_OPENAI_ENDPOINT="https://<resource-name>.openai.azure.com/"
export AZURE_OPENAI_API_KEY="<secret>"
export AZURE_OPENAI_DEPLOYMENT="<deployment-name>"
export AZURE_OPENAI_API_VERSION="<api-version>"
uv run uvicorn app.main:app --reload
```

Luego repite el mismo flujo: registrar/login, sembrar datos mínimos (1 workout
log, 3 nutrition logs, 1 measurement), `POST /recommendations/weekly` y
`GET /recommendations/latest` para confirmar la persistencia. Sin las 4
variables → `503`; si Azure responde pero con contenido no parseable → `502`.

No incluyas valores reales de `AZURE_OPENAI_API_KEY` (ni ningún otro secreto)
en el repositorio.

### Decisiones técnicas — Bloque 5.2

1. **`FakeAIProvider` se conserva como default**: mantiene el flujo local y de
   tests 100% determinista y sin dependencias externas.
2. **`AI_PROVIDER` como feature switch**: cambiar de fake a azure es una
   variable de entorno, no un cambio de código.
3. **`AzureOpenAIProvider` aislado en su propia clase**: el resto del sistema
   (rutas, servicio, tests) solo conoce la interfaz `AIProvider`.
4. **Validación de configuración solo cuando se usa `azure`**: el provider fake
   nunca exige `AZURE_OPENAI_*`.
5. **Validación movida de `__init__` a `generate`**: para que el error de
   configuración ocurra dentro del `try/except` de la ruta (y se traduzca a un
   `503` controlado) en lugar de fallar al resolver la dependency de FastAPI.
6. **Se pide `response_format={"type": "json_object"}`**: refuerza a nivel de
   API la instrucción textual del prompt de responder solo JSON.
7. **La respuesta se valida con `AIGeneratedContent` antes de persistir**:
   JSON válido pero con forma incorrecta nunca llega a la base de datos.
8. **No se hacen llamadas reales a Azure en tests**: se inyecta un cliente fake
   (`AsyncAzureOpenAI` sustituido por un mock) en `AzureOpenAIProvider.__init__`.
9. **Errores del SDK se mapean a excepciones propias** (`AIProviderError` y
   subclases) antes de llegar a la ruta, para no exponer detalles internos del
   SDK ni depender de sus tipos en el resto del código.
10. **No se loggean prompts completos ni secretos**: prepara el camino para
    activar Azure Monitor / Application Insights más adelante sin filtrar
    datos sensibles del usuario ni credenciales.
11. **Esto deja la app lista para Azure Container Apps**: el provider ya lee
    toda su configuración desde variables de entorno, que es exactamente cómo
    se inyectan secretos en Container Apps (env vars / secrets), sin cambios
    de código adicionales.

### Limitaciones conocidas

- No hay streaming de la respuesta (se pide la respuesta completa de una vez).
- No hay caché de respuestas ni límite de rate por usuario más allá del
  `unique(user_id, week_start, week_end)` existente.
- El retry ante errores transitorios lo maneja el SDK (`AZURE_OPENAI_MAX_RETRIES`);
  no hay backoff/retry adicional a nivel de aplicación.
- No se valida el modelo/deployment contra un listado conocido; un `deployment`
  mal escrito fallará como `AIProviderError` (502) al llamar a Azure.

### Criterios de aceptación

- [x] `openai` agregado como dependencia (`uv add openai`).
- [x] `FakeAIProvider` sigue siendo el default (`AI_PROVIDER=fake`).
- [x] `AzureOpenAIProvider.generate` implementado con `AsyncAzureOpenAI`.
- [x] `AI_PROVIDER=fake` no requiere credenciales.
- [x] `AI_PROVIDER=azure` requiere las 4 variables `AZURE_OPENAI_*`.
- [x] No hay secretos hardcodeados; todo viene de variables de entorno.
- [x] Se pide y valida una respuesta JSON estructurada (`AIGeneratedContent`).
- [x] JSON inválido o vacío no se persiste.
- [x] Timeout/error del provider se manejan de forma controlada (`503`/`502`).
- [x] Tests usan mocks/clientes inyectados; ninguna llamada real a Azure.
- [x] `uv run pytest` y `uv run ruff check .` en verde.
- [x] README actualizado con fake vs Azure, variables, curl y manejo de errores.

## Probar los endpoints con curl

```bash
curl http://localhost:8000/health

# Registrar usuario
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"felipe@example.com","name":"Felipe Garcia","password":"StrongPassword123","goal":"body recomposition"}'

# Login y guardar el token en una variable de shell
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"felipe@example.com","password":"StrongPassword123"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

# Consultar el usuario autenticado
curl http://localhost:8000/auth/me -H "Authorization: Bearer $TOKEN"

# Probar con un token inválido -> 401
curl -i http://localhost:8000/auth/me -H "Authorization: Bearer token-invalido"

curl http://localhost:8000/users/<uuid-devuelto>

# Crear workout plan con días y ejercicios
curl -s -X POST http://localhost:8000/workout-plans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "4-Day Body Recomposition Plan",
    "goal": "body recomposition",
    "active": true,
    "days": [
      {
        "day_of_week": 1,
        "title": "Upper Body",
        "exercises": [
          {"name": "Pull-ups", "muscle_group": "back", "target_sets": 4, "target_reps": "6-8"},
          {"name": "Dumbbell Press", "muscle_group": "chest", "target_sets": 3, "target_reps": "8-10"}
        ]
      },
      {
        "day_of_week": 3,
        "title": "Lower Body",
        "exercises": [
          {"name": "Goblet Squat", "muscle_group": "legs", "target_sets": 4, "target_reps": "10-12"}
        ]
      }
    ]
  }'

# Listar workout plans del usuario autenticado
curl http://localhost:8000/workout-plans -H "Authorization: Bearer $TOKEN"

# Obtener detalle de un workout plan (usar el id devuelto por el POST anterior)
curl http://localhost:8000/workout-plans/<plan-id> -H "Authorization: Bearer $TOKEN"

# Probar acceso sin token -> 401
curl -i http://localhost:8000/workout-plans

# Probar acceso a un plan inexistente -> 404
curl -i http://localhost:8000/workout-plans/00000000-0000-0000-0000-000000000000 \
  -H "Authorization: Bearer $TOKEN"

# Extraer un exercise_id del plan recién creado (ajustar <plan-id>)
EXERCISE_ID=$(curl -s http://localhost:8000/workout-plans/<plan-id> \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["days"][0]["exercises"][0]["id"])')

# Crear workout log
curl -s -X POST http://localhost:8000/workout-logs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "exercise_id": "'"$EXERCISE_ID"'",
    "performed_at": "2026-07-03T18:30:00",
    "sets": 4,
    "reps": 8,
    "weight": 12.5,
    "notes": "Felt strong, good control on last set."
  }'

# Listar workout logs del usuario autenticado
curl http://localhost:8000/workout-logs -H "Authorization: Bearer $TOKEN"

# Listar workout logs con filtros de fecha
curl "http://localhost:8000/workout-logs?date_from=2026-07-01&date_to=2026-07-07" \
  -H "Authorization: Bearer $TOKEN"

# Consultar el resumen de workout logs
curl "http://localhost:8000/workout-logs/summary" -H "Authorization: Bearer $TOKEN"

# Probar acceso sin token -> 401
curl -i -X POST http://localhost:8000/workout-logs -d '{}'

# Probar con un ejercicio inexistente -> 404
curl -i -X POST http://localhost:8000/workout-logs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "exercise_id": "00000000-0000-0000-0000-000000000000",
    "performed_at": "2026-07-03T18:30:00",
    "sets": 3,
    "reps": 10
  }'

# Crear nutrition log
curl -s -X POST http://localhost:8000/nutrition-logs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-07-03",
    "calories": 1850,
    "protein": 105.5,
    "carbs": 210,
    "fats": 55,
    "notes": "Good protein intake, slightly low calories."
  }'

# Intentar crear un segundo nutrition log para la misma fecha -> 409
curl -i -X POST http://localhost:8000/nutrition-logs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-07-03",
    "calories": 1900,
    "protein": 100,
    "carbs": 200,
    "fats": 50
  }'

# Listar nutrition logs del usuario autenticado
curl http://localhost:8000/nutrition-logs -H "Authorization: Bearer $TOKEN"

# Listar nutrition logs con filtros de fecha
curl "http://localhost:8000/nutrition-logs?date_from=2026-07-01&date_to=2026-07-07" \
  -H "Authorization: Bearer $TOKEN"

# Consultar el resumen de nutrition logs
curl "http://localhost:8000/nutrition-logs/summary?date_from=2026-07-01&date_to=2026-07-07" \
  -H "Authorization: Bearer $TOKEN"

# Probar acceso sin token -> 401
curl -i http://localhost:8000/nutrition-logs

# Crear body measurement
curl -s -X POST http://localhost:8000/measurements \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-07-01",
    "weight": 71.0,
    "waist": 83.2,
    "body_fat_estimate": 25.0,
    "notes": "Morning measurement after cardio day."
  }'

# Intentar crear una segunda medición para la misma fecha -> 409
curl -i -X POST http://localhost:8000/measurements \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-07-01",
    "weight": 70.8
  }'

# Crear varias mediciones en fechas distintas
curl -s -X POST http://localhost:8000/measurements \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-07-31",
    "weight": 70.2,
    "waist": 82.5,
    "body_fat_estimate": 24.5
  }'

# Listar body measurements del usuario autenticado
curl http://localhost:8000/measurements -H "Authorization: Bearer $TOKEN"

# Listar body measurements con filtros de fecha
curl "http://localhost:8000/measurements?date_from=2026-07-01&date_to=2026-07-31" \
  -H "Authorization: Bearer $TOKEN"

# Consultar el progreso físico (primera vs última medición del rango)
curl "http://localhost:8000/measurements/progress?date_from=2026-07-01&date_to=2026-07-31" \
  -H "Authorization: Bearer $TOKEN"

# Probar acceso sin token -> 401
curl -i http://localhost:8000/measurements

# Consultar el weekly summary (consolida workouts + nutrición + mediciones de la semana)
curl "http://localhost:8000/weekly-summary?week_start=2026-07-01" \
  -H "Authorization: Bearer $TOKEN"

# Weekly summary de una semana sin datos -> respuesta controlada (200), no error
curl "http://localhost:8000/weekly-summary?week_start=2099-01-01" \
  -H "Authorization: Bearer $TOKEN"

# Probar acceso sin token -> 401
curl -i "http://localhost:8000/weekly-summary?week_start=2026-07-01"

# Probar sin week_start -> 422
curl -i "http://localhost:8000/weekly-summary" -H "Authorization: Bearer $TOKEN"

# --- AI Weekly Recommendations (Bloque 5.1) ---
# Para que la generación funcione, la semana debe estar "ready": >=1 workout log,
# >=3 nutrition logs y >=1 medición dentro de la semana (ver curls anteriores).

# Generar la recomendación semanal (usa el fake provider por defecto)
curl -X POST http://localhost:8000/recommendations/weekly \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"week_start":"2026-07-01"}'

# Consultar la última recomendación del usuario autenticado
curl http://localhost:8000/recommendations/latest -H "Authorization: Bearer $TOKEN"

# Intentar regenerar la misma semana -> 409
curl -i -X POST http://localhost:8000/recommendations/weekly \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"week_start":"2026-07-01"}'

# Generar para una semana sin datos suficientes -> 422 (con missing_data)
curl -i -X POST http://localhost:8000/recommendations/weekly \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"week_start":"2099-01-01"}'

# Probar acceso sin token -> 401
curl -i -X POST http://localhost:8000/recommendations/weekly \
  -H "Content-Type: application/json" \
  -d '{"week_start":"2026-07-01"}'
```

Casos de error:
- `POST /auth/register` con un email ya registrado → `409 Conflict`.
- `POST /auth/login` con credenciales inválidas → `401 Unauthorized`.
- `GET /auth/me` sin token, con token inválido/expirado, o con usuario inexistente → `401 Unauthorized`.
- `GET /users/{id}` con un id que no existe → `404 Not Found`.
- `POST /workout-plans` sin token → `401 Unauthorized`; con payload inválido (ej. `day_of_week` fuera de `1-7`) → `422 Unprocessable Entity`.
- `GET /workout-plans/{plan_id}` con un id que no existe o pertenece a otro usuario → `404 Not Found` (mismo mensaje en ambos casos, para no revelar la existencia de planes ajenos).
- `POST /workout-logs` sin token → `401 Unauthorized`; con un `exercise_id` que no existe o pertenece a otro usuario → `404 Exercise not found`; con payload inválido (ej. `sets: 0`) → `422 Unprocessable Entity`.
- `POST /nutrition-logs` sin token → `401 Unauthorized`; con una fecha que ya tiene log para ese usuario → `409 Nutrition log already exists for this date`; con payload inválido (ej. `calories: -1`) → `422 Unprocessable Entity`.
- `POST /measurements` sin token → `401 Unauthorized`; con una fecha que ya tiene medición para ese usuario → `409 Body measurement already exists for this date`; con payload inválido (ej. `weight: 0` o `body_fat_estimate: 200`) → `422 Unprocessable Entity`.
- `GET /weekly-summary` sin token → `401 Unauthorized`; sin `week_start` o con formato inválido → `422 Unprocessable Entity`.
- `POST /recommendations/weekly` sin token → `401 Unauthorized`; sin `week_start`/formato inválido → `422`; datos insuficientes → `422` (con `missing_data`); recomendación ya existente para esa semana → `409 Recommendation already exists for this week`; respuesta inválida del AI provider → `502`.
- `GET /recommendations/latest` sin token → `401 Unauthorized`; sin recomendaciones → `404 Recommendation not found`.

También disponible la documentación interactiva en `http://localhost:8000/docs`.

## Tests

```bash
docker compose up -d db   # los tests corren contra Postgres real
uv run pytest
```

> Nota: los tests de auth (`app/tests/conftest.py`) recrean (`drop_all` + `create_all`)
> el esquema en la base de datos apuntada por `DATABASE_URL` antes de cada test, para
> partir de un estado limpio. Esto es intencional en esta etapa temprana del proyecto;
> si el proyecto crece, conviene apuntar los tests a una base de datos dedicada
> (ej. `fittrack_test`) en vez de la base de desarrollo.

## Lint

```bash
uv run ruff check .
```

## Decisiones técnicas — Bloque 2.2

**¿Por qué JWT para este MVP?** Es stateless: no requiere tabla de sesiones ni
almacenamiento server-side, y es el estándar de facto para APIs REST consumidas por
un cliente mobile (Expo/React Native). Para el alcance actual (un solo backend,
sin necesidad de revocar sesiones activamente) es la opción más simple que cumple
el requisito.

**¿Por qué todavía sin refresh tokens?** Añaden estado (una tabla de refresh tokens,
rotación, revocación) y complejidad que no se necesita mientras no exista un cliente
mobile real consumiendo la API en sesiones largas. Se agregarán cuando el flujo de
mobile lo requiera.

**¿Por qué todavía sin OAuth?** OAuth resuelve "confiar en un proveedor externo de
identidad", un problema que este proyecto no tiene todavía — el objetivo actual es
demostrar un flujo de auth propio, explicable de punta a punta.

**¿Por qué todavía sin roles/permisos?** Solo existe un tipo de usuario. Introducir
roles antes de tener un caso de uso real que los necesite sería sobreingeniería.

**¿Por qué `user_id` no debe venir del cliente en rutas protegidas?** Si el cliente
pudiera enviar `user_id` libremente, cualquier usuario autenticado podría leer o
modificar datos de otro con solo cambiar ese valor (un IDOR clásico). El `user_id`
debe derivarse siempre del token verificado en el servidor, nunca de un campo del
request.

**¿Por qué `get_current_user` es clave para los próximos módulos?** Es el único punto
de entrada que traduce "un Bearer token válido" en "un objeto `User` de confianza".
Los módulos de workouts, nutrition, measurements y AI recommendations dependerán de
él (`Depends(get_current_user)`) para asociar cada registro al usuario autenticado,
sin duplicar lógica de validación de token en cada ruta.

**Manejo de secretos: local vs Azure.** En local, `JWT_SECRET_KEY` vive en `.env`
(gitignored) y se lee vía `pydantic-settings`. En Azure, el mismo nombre de variable
se inyectará como secreto en Container Apps (o se leerá desde Azure Key Vault) en vez
de un archivo `.env` — el código de `core/config.py` no cambia, solo el origen del
valor en runtime.

## Decisiones técnicas — Bloque 2.3

**¿Por qué los workout plans deben estar asociados al usuario autenticado?**
Un plan de entrenamiento es un dato privado del usuario. Asociarlo a
`current_user.id` (nunca a un valor recibido del cliente) garantiza aislamiento
entre usuarios: cada quien solo puede ver y crear sus propios planes.

**¿Por qué el cliente no debe enviar `user_id`?** Igual que en el resto de la API
(ver decisión equivalente en el Bloque 2.2): si el cliente pudiera enviar `user_id`
libremente, cualquier usuario autenticado podría crear o leer datos a nombre de
otro con solo cambiar ese campo (IDOR). El `user_id` se deriva siempre del JWT
verificado por `get_current_user`.

**¿Por qué modelos separados para `WorkoutPlan`, `WorkoutDay` y `Exercise`?**
Reflejan una relación 1-N-N real (un plan tiene varios días, un día tiene varios
ejercicios). Modelarlos como tablas separadas en vez de columnas JSON permite
consultas relacionales eficientes, integridad referencial vía foreign keys, y que
cada ejercicio tenga un `id` propio y estable — necesario para que el Bloque 2.4
(workout logs) pueda referenciarlo.

**¿Por qué crear el plan completo en una transacción?** El servicio construye el
grafo completo (`WorkoutPlan` con sus `days` y `exercises` anidados) en memoria y
hace un único `session.commit()`. O se crea el plan completo, o no se crea nada —
evita dejar un plan a medias (por ejemplo, con días pero sin ejercicios) si algo
falla a mitad de la operación.

**¿Por qué `target_reps` es string y no integer?** Los objetivos de repeticiones
reales no siempre son un número fijo: `"8-10"` (rango), `"AMRAP"` (as many reps as
possible) o `"30 seconds"` (tiempo) son valores legítimos que un campo `integer` no
podría representar.

**¿Cómo prepara esta estructura los workout logs (Bloque 2.4)?** Los logs
registrarán series/reps/peso realmente ejecutados por sesión, referenciando el
`exercise_id` de un `Exercise` ya creado aquí. Tener ejercicios con `id` propio
(en vez de solo texto embebido en el plan) es lo que hace posible esa referencia.

**¿Cómo prepara esta estructura las recomendaciones de IA?** La combinación
`goal` del plan + estructura de días/ejercicios (grupo muscular, sets, reps) le da
a Azure OpenAI contexto estructurado y consultable sobre lo que el usuario
efectivamente está entrenando, en vez de tener que inferirlo de texto libre.

## Decisiones técnicas — Bloque 2.4

**¿Por qué `WorkoutLog` pertenece directamente al usuario y no cuelga de un
`WorkoutPlan`?** Un log es un hecho histórico de actividad, no una definición de
entrenamiento. El usuario puede editar o borrar su plan, y eso no debería alterar
ni el significado ni la disponibilidad de lo que ya entrenó. Consultar "todo lo
que el usuario ha entrenado" es un scan directo por `user_id`, sin depender de que
el plan original siga existiendo.

**¿Por qué `exercise_id` se valida contra ownership indirecto?** Un `Exercise` no
tiene `user_id` propio — pertenece a un `WorkoutDay`, que pertenece a un
`WorkoutPlan`, que sí tiene `user_id`. Antes de crear un log se hace un JOIN
(`Exercise → WorkoutDay → WorkoutPlan`) para confirmar que ese ejercicio es de un
plan del usuario autenticado. Sin esta validación, cualquier usuario podría
registrar logs usando el `exercise_id` de otro usuario (un IDOR indirecto).

**¿Por qué el cliente no debe enviar `user_id`?** Misma razón que en los bloques
anteriores: el `user_id` se deriva siempre de `current_user.id` (vía
`get_current_user`), nunca de un campo del request.

**¿Por qué un log agregado por ejercicio y no por serie individual en este MVP?**
Un registro por ejercicio (`sets`, `reps`, `weight` totales/representativos de la
sesión) es suficiente para medir volumen y cumplimiento, que es lo que necesitan
el dashboard y las recomendaciones de IA en esta etapa. Modelar cada serie
individual (con su propio peso y RPE) añade complejidad de captura y de esquema
sin un caso de uso que lo requiera todavía.

**¿Por qué no crear todavía una tabla de sets individuales?** Es una optimización
futura (útil para progressive overload serie a serie), pero introducirla ahora
sería anticipar un requisito que no existe: ni el dashboard ni las
recomendaciones semanales de IA necesitan ese nivel de granularidad hoy.

**¿Por qué `weight` es nullable?** Varios ejercicios se entrenan con peso corporal
(pull-ups, flexiones, planchas), donde no hay un valor de peso adicional que
registrar. Forzar un valor obligaría a inventar un `0` que no representa lo mismo
que "no aplica".

**¿Cómo prepara este módulo los dashboards?** `GET /workout-logs/summary` entrega
agregados (`total_logs`, `total_sets`, `total_reps`, `unique_exercises`,
`workout_days`) filtrables por rango de fechas — el mismo shape que necesitaría
una tarjeta de métricas semanales en el cliente mobile, sin que el cliente tenga
que descargar y sumar los logs individuales.

**¿Cómo prepara este módulo las recomendaciones semanales de IA?** Los logs por
rango de fechas (qué se entrenó, cuánto volumen, con qué frecuencia) más los
agregados de `/summary` son el primer input estructurado y consultable de
actividad real del usuario — la base sobre la que un prompt semanal a Azure
OpenAI podrá razonar sobre adherencia y progreso, en vez de inferirlo de texto
libre.

## Decisiones técnicas — Bloque 2.5

**¿Por qué `NutritionLog` pertenece directamente al usuario?** Los macros diarios
son un atributo del usuario, no de un plan o ejercicio — no hay una cadena de
ownership indirecto que atravesar (a diferencia de `WorkoutLog → Exercise →
WorkoutDay → WorkoutPlan`). La FK es directa a `users.id`.

**¿Por qué el cliente no debe enviar `user_id`?** Misma razón que en el resto de
la API: el `user_id` se deriva siempre de `current_user.id` (vía
`get_current_user`), nunca de un campo del request — evita que un usuario
autenticado pueda leer o escribir logs de otro (IDOR).

**¿Por qué un log diario por usuario (Opción A) en este MVP?** FitTrack AI se
enfoca en progreso semanal y recomendaciones agregadas, no en tracking granular
de comidas individuales. Un registro por día da un resumen limpio y sin
ambigüedad para el dashboard y para la IA, sin necesitar un concepto de
`meal_type` todavía.

**¿Por qué `unique(user_id, date)`?** Garantiza a nivel de base de datos que no
puedan existir dos logs del mismo usuario para el mismo día, sin depender solo
de la validación en el service. Simplifica los agregados: cada día contribuye
exactamente un punto de datos a `days_logged`, `avg_*` y `total_*`.

**¿Por qué `protein`, `carbs` y `fats` son numeric/decimal y `calories` es
integer?** Los macros en gramos admiten valores fraccionarios reales (ej.
`105.5g` de proteína), mientras que las calorías se reportan y consumen
convencionalmente como un número entero.

**¿Cómo prepara este módulo los dashboards?** `GET /nutrition-logs/summary`
entrega promedios y totales de calorías y macros filtrables por rango de
fechas — el mismo shape que necesitaría una tarjeta de cumplimiento nutricional
semanal en el cliente mobile, sin que el cliente tenga que descargar y sumar
los logs individuales.

**¿Cómo prepara este módulo las recomendaciones semanales de IA?** Junto con
`/workout-logs/summary`, este es el segundo input estructurado de actividad
real del usuario (qué comió, cuánto, con qué consistencia) que un prompt
semanal a Azure OpenAI podrá usar para razonar sobre cumplimiento de macros y
sugerir ajustes, en vez de inferirlo de texto libre.

**Limitaciones conocidas de no registrar comidas individuales:** no es posible
analizar distribución de macros por comida (desayuno/almuerzo/cena/snacks), ni
identificar qué alimentos específicos componen el día, ni corregir un registro
parcial sin sobrescribir el día completo. Es una limitación aceptada para este
MVP; el modelo (Opción B, múltiples logs por día con `meal_type`) podría
introducirse más adelante si el caso de uso lo justifica.

## Decisiones técnicas — Bloque 2.6

**¿Por qué `BodyMeasurement` pertenece directamente al usuario?** El progreso
físico (peso, cintura, grasa corporal) es un atributo del propio usuario, no de
un plan ni de un ejercicio — no hay cadena de ownership indirecto que atravesar
(a diferencia de `WorkoutLog → Exercise → WorkoutDay → WorkoutPlan`). La FK es
directa a `users.id`.

**¿Por qué el cliente no debe enviar `user_id`?** Misma razón que en el resto de
la API: el `user_id` se deriva siempre de `current_user.id` (vía
`get_current_user`), nunca de un campo del request — evita que un usuario
autenticado pueda leer o escribir mediciones de otro (IDOR).

**¿Por qué una medición diaria por usuario en este MVP?** FitTrack AI mide
progreso en escala semanal/mensual, donde un punto de datos por día es más que
suficiente. Una sola medición diaria da una serie temporal limpia y sin
ambigüedad para graficar tendencias y para que la IA razone sobre progreso, sin
necesitar desambiguar entre varias mediciones del mismo día.

**¿Por qué `unique(user_id, date)`?** Garantiza a nivel de base de datos que no
existan dos mediciones del mismo usuario para el mismo día, sin depender solo de
la validación en el service. Además hace determinista el endpoint de progreso:
cada fecha aporta exactamente un punto, así que "primera" y "última" medición del
rango están bien definidas.

**¿Por qué `waist` y `body_fat_estimate` son opcionales?** No todos los usuarios
miden cintura ni estiman grasa corporal en cada registro — muchos solo se pesan.
Forzar esos campos obligaría a inventar valores que no representan una medición
real. `weight`, en cambio, es el mínimo indispensable de una medición y por eso
es requerido.

**¿Por qué el progreso compara primera vs última medición del rango?** Es la
forma más directa y explicable de responder "¿cuánto cambié en este periodo?":
el delta entre el primer y el último registro del rango. No requiere ajustar
regresiones ni promediar, y es exactamente lo que una tarjeta de progreso o un
prompt de IA necesitan comunicar. Cuando un campo opcional falta en alguno de los
dos extremos, su cambio se devuelve como `null` en vez de un `0` engañoso.

**¿Cómo prepara este módulo los dashboards?** `GET /measurements` entrega la serie
temporal lista para graficar tendencias de peso/cintura/grasa, y
`GET /measurements/progress` entrega los deltas del periodo ya calculados en el
servidor — el mismo shape que necesitaría una tarjeta de progreso en el cliente
mobile, sin que este tenga que descargar y comparar mediciones manualmente.

**¿Cómo prepara este módulo las recomendaciones semanales de IA?** Junto con
`/workout-logs/summary` (actividad) y `/nutrition-logs/summary` (nutrición), el
progreso físico cierra el triángulo de inputs estructurados: un prompt semanal a
Azure OpenAI podrá cruzar "cuánto entrenó y comió" con "cómo cambió su cuerpo"
para razonar sobre resultados reales y sugerir ajustes, en vez de inferirlo de
texto libre.

**Limitaciones conocidas de no registrar mediciones más avanzadas:** por ahora no
se capturan otras circunferencias (pecho, brazo, cadera, muslo), ni métodos de
medición de grasa (pliegues, bioimpedancia, DEXA), ni fotos de progreso (Bloque
futuro). Tampoco se calculan métricas derivadas (IMC, masa magra estimada). Es una
limitación aceptada para este MVP; el esquema puede extenderse con más columnas o
una tabla de circunferencias si el caso de uso lo justifica.

## Decisiones técnicas — Bloque 2.7

**¿Por qué este bloque no debe llamar todavía a IA?** Separar la "capa de datos"
de la "capa de inferencia" mantiene este endpoint determinista, barato y fácil de
testear con asserts exactos. La IA se añade encima después, sin tener que
reescribir la agregación ni sus tests.

**¿Por qué consolidar datos antes de crear recomendaciones?** Un prompt de IA
necesita un input único, estable y validado — no tres llamadas a `/summary` y
`/progress` que el propio módulo de IA tendría que orquestar y sincronizar por
rango de fechas. Consolidar primero da un contrato limpio y reutilizable.

**¿Por qué `week_start` debe venir del cliente?** Qué semana se está mirando es
una decisión de producto/UI (el usuario navega el dashboard semana a semana); el
backend no debe adivinar cuál es "la semana actual" del usuario.

**¿Por qué `week_end` se calcula en backend?** Garantiza siempre una semana de
7 días exactos y evita que el cliente envíe rangos arbitrarios (ej. 3 días o 40
días) que romperían el contrato de "resumen semanal". Es una regla de negocio
centralizada en un solo lugar.

**¿Por qué el endpoint debe funcionar aunque falten datos?** Un dashboard nunca
debería romperse porque el usuario no registró nada esa semana. Se devuelve una
respuesta controlada (ceros y `null`, nunca un error) — el mismo criterio ya
aplicado en `/nutrition-logs/summary` y `/measurements/progress`.

**¿Por qué agregar `data_quality`?** Hace explícita, en un solo bloque, la
completitud de los datos de la semana, para que tanto el dashboard mobile como
el futuro servicio de IA puedan decidir cómo actuar sin tener que re-inspeccionar
manualmente cada agregado.

**¿Por qué `is_ready_for_ai_recommendation` debe ser explícito?** Evita que el
módulo de IA futuro genere recomendaciones sobre datos casi inexistentes (ej. un
solo log de nutrición). La regla es simple, auditable y vive en un solo lugar
(`weekly_summary_service.py`) en vez de una heurística oculta dentro del prompt.

**¿Cómo sirve este endpoint al dashboard mobile?** Una sola llamada
(`GET /weekly-summary?week_start=...`) entrega todo lo que necesita una vista
semanal: entrenamiento, nutrición y progreso físico, ya agregados y con la señal
de qué tan completos están los datos.

**¿Cómo sirve este endpoint a `POST /recommendations/weekly` (Bloque 5.1)?** Será
su input directo: el servicio de IA llamará a `weekly_summary_service` (o al
propio endpoint), revisará `data_quality.is_ready_for_ai_recommendation`, y solo
si es `true` construirá el prompt hacia Azure OpenAI. Si es `false`, puede
devolver un mensaje explicando qué falta en vez de forzar una recomendación con
datos insuficientes.

**Limitaciones conocidas:** el rango de la semana es fijo en 7 días a partir de
`week_start` (no se admiten semanas parciales ni rangos custom); el reporte se
recalcula en cada request (no hay caché ni tabla de snapshots semanales); y no
persiste historial de "resúmenes generados" — cada llamada recalcula desde los
logs crudos.

## Decisiones técnicas — Bloque 5.1

**¿Por qué usar el weekly summary como input en vez de consultar las tablas
directamente desde el servicio de IA?** El summary ya es un contrato único,
validado y con `data_quality` calculado. Reutilizarlo evita duplicar lógica de
agregación y sincronización de rangos en el módulo de IA, y garantiza que la IA
ve exactamente los mismos números que el dashboard.

**¿Por qué validar `data_quality` antes de generar?** Genera recomendaciones
solo cuando hay señal real (≥1 workout, ≥3 días de nutrición, ≥1 medición). Sin
esto la IA "alucinaría" tendencias sobre uno o dos datos. La regla vive en un
solo lugar (`weekly_summary_service`) y es auditable, no una heurística escondida
en el prompt.

**¿Por qué persistir las recomendaciones?** Son un artefacto de producto: el
usuario debe poder volver a verlas, se muestran en el historial del dashboard, y
no queremos re-llamar (ni re-pagar) a un modelo para releer algo ya generado.
Además fija la recomendación en el tiempo aunque los logs crudos cambien después.

**¿Por qué `unique(user_id, week_start, week_end)`?** Una semana tiene una única
recomendación por usuario. La constraint hace imposible duplicar a nivel de base
de datos, y el servicio la traduce a un `409` claro en vez de acumular filas.

**¿Por qué no aceptar `user_id` del cliente?** Seguridad y scoping estricto: el
dueño de los datos es siempre `current_user`. Aceptar `user_id` abriría un IDOR
(un usuario generando/leyendo recomendaciones de otro).

**¿Por qué un fake provider en tests/local?** Hace el flow end-to-end
determinista, gratis y sin dependencia de red ni credenciales. Los tests
asertan comportamiento (persistencia, 201/409/422/404/502, scoping) sin llamar
nunca a Azure OpenAI.

**¿Por qué aislar la IA en `ai_provider.py`?** El resto de la app depende de una
interfaz (`AIProvider.generate(summary) -> str`), no de un SDK concreto. Cambiar
de fake a Azure OpenAI (Bloque 5.2) es cambiar una implementación y una variable
de entorno, sin tocar routes ni el service de dominio. El provider se inyecta vía
`Depends(get_ai_provider)`, lo que además permite sobrescribirlo en tests.

**¿Por qué la IA debe devolver JSON estructurado?** Da un contrato parseable y
validable (`AIGeneratedContent` con Pydantic). Si el modelo devuelve algo que no
es JSON válido o no cumple el esquema, se detecta y se traduce a un `502`
controlado en vez de persistir basura o romper la respuesta.

**¿Por qué evitar consejos médicos o diagnósticos?** Es una app de seguimiento de
hábitos, no un producto sanitario. El prompt prohíbe explícitamente diagnósticos,
tratamientos, cambios extremos y comentarios sobre el cuerpo; y toda respuesta
lleva una `safety_notes` garantizada por backend, reduciendo riesgo legal y de
producto.

**¿Cómo prepara este bloque la integración con Azure OpenAI?** `AzureOpenAIProvider`
ya existe estructuralmente, lee su configuración de `settings`, y el prompt
seguro (`build_prompt`) ya está escrito; `AI_PROVIDER` selecciona el provider.
El Bloque 5.2 implementa la llamada real (con timeouts, reintentos y manejo de
errores) dentro de `generate` — ver
[Decisiones técnicas — Bloque 5.2](#decisiones-técnicas--bloque-52).

**Limitaciones conocidas:** no hay regeneración (una semana = una recomendación,
`409` si ya existe); no hay paginación ni endpoint de historial completo (solo
`latest`); y la recomendación se congela al generarse (no se recalcula si los
logs cambian después).

## Criterios de aceptación de este bloque

- [x] `uv sync` instala todo sin errores.
- [x] `docker compose up` levanta `db` + `api` sanos.
- [x] `GET /health` responde `{"status":"ok","service":"fittrack-ai-api","version":"0.1.0"}`.
- [x] `User` tiene `password_hash`; las passwords se guardan hasheadas (argon2).
- [x] `password_hash` nunca aparece en ninguna respuesta.
- [x] `POST /auth/register` crea usuario; email duplicado devuelve `409 Conflict`.
- [x] `POST /auth/login` devuelve un JWT; credenciales inválidas devuelven `401 Unauthorized`.
- [x] `GET /auth/me` devuelve el usuario autenticado; sin token/token inválido/usuario
      inexistente devuelve `401 Unauthorized`.
- [x] Existe la dependency `get_current_user` (`app/api/deps.py`).
- [x] `GET /users/{id}` sigue funcionando; devuelve `404 User not found` si no existe.
- [x] Migración Alembic agrega `password_hash` a `users`.
- [x] Existen los modelos `WorkoutPlan`, `WorkoutDay` y `Exercise`.
- [x] Migración Alembic para `workout_plans`, `workout_days` y `exercises` aplicada.
- [x] `POST /workout-plans` crea un plan asociado al usuario autenticado; el cliente
      no envía `user_id`.
- [x] `GET /workout-plans` lista solo los planes del usuario autenticado.
- [x] `GET /workout-plans/{plan_id}` devuelve el detalle anidado (días + ejercicios).
- [x] Un usuario no puede acceder a los planes de otro usuario (`404`).
- [x] Rutas de `/workout-plans` devuelven `401` sin token.
- [x] Payload inválido devuelve `422`.
- [x] Existe el modelo `WorkoutLog` con migración Alembic aplicada.
- [x] `POST /workout-logs` crea logs asociados al usuario autenticado; el cliente
      no envía `user_id`.
- [x] Se valida que el `exercise_id` pertenezca a un plan del usuario autenticado;
      un usuario no puede registrar logs sobre ejercicios de otro usuario (`404`).
- [x] `GET /workout-logs` lista solo los logs del usuario autenticado.
- [x] Los filtros `date_from` y `date_to` funcionan en `GET /workout-logs` y
      `GET /workout-logs/summary`.
- [x] `GET /workout-logs/summary` devuelve agregados básicos correctos.
- [x] Rutas de `/workout-logs` devuelven `401` sin token; payload inválido
      devuelve `422`.
- [x] Existe el modelo `NutritionLog` con migración Alembic aplicada.
- [x] `POST /nutrition-logs` crea logs asociados al usuario autenticado; el
      cliente no envía `user_id`.
- [x] Se usa `unique(user_id, date)`; un log duplicado para el mismo usuario y
      fecha devuelve `409 Conflict`.
- [x] Dos usuarios diferentes pueden registrar la misma fecha sin conflicto.
- [x] `GET /nutrition-logs` lista solo los logs del usuario autenticado.
- [x] Los filtros `date_from` y `date_to` funcionan en `GET /nutrition-logs` y
      `GET /nutrition-logs/summary`.
- [x] `GET /nutrition-logs/summary` devuelve agregados básicos (promedios y
      totales) correctos.
- [x] Rutas de `/nutrition-logs` devuelven `401` sin token; payload inválido
      devuelve `422`.
- [x] Existe el modelo `BodyMeasurement` con migración Alembic aplicada.
- [x] `POST /measurements` crea mediciones asociadas al usuario autenticado; el
      cliente no envía `user_id`.
- [x] Se usa `unique(user_id, date)`; una medición duplicada para el mismo usuario
      y fecha devuelve `409 Conflict`.
- [x] Dos usuarios diferentes pueden registrar la misma fecha sin conflicto.
- [x] `GET /measurements` lista solo las mediciones del usuario autenticado.
- [x] Los filtros `date_from` y `date_to` funcionan en `GET /measurements` y
      `GET /measurements/progress`.
- [x] `GET /measurements/progress` devuelve los cambios entre la primera y la
      última medición del rango; sin datos devuelve una respuesta controlada
      (`measurements_count: 0` y el resto `null`).
- [x] Rutas de `/measurements` devuelven `401` sin token; payload inválido
      devuelve `422`.
- [x] Existe `GET /weekly-summary`, protegido con Bearer token; el cliente no
      envía `user_id`, se usa `current_user.id`.
- [x] `week_start` es requerido y válido; sin él o con formato inválido devuelve
      `422`. `week_end` se calcula siempre en backend (`week_start + 6 días`).
- [x] Consolida correctamente workout logs, nutrition logs y body measurements
      de la semana.
- [x] Sin datos en la semana, devuelve una respuesta controlada (agregados en
      `0`, promedios/deltas en `null`), nunca un error.
- [x] Incluye `data_quality` con `is_ready_for_ai_recommendation` calculado con
      la regla explícita (≥1 workout log, ≥3 nutrition logs, ≥1 medición).
- [x] Un usuario no ve datos semanales de otro usuario.
- [x] Existe el modelo `AIRecommendation` con migración Alembic aplicada
      (FK a `users`, índices en `user_id` y `week_start`, unique
      `user_id + week_start + week_end`).
- [x] `POST /recommendations/weekly` está protegido; el cliente solo envía
      `week_start`, `week_end` se calcula en backend y `user_id` sale de
      `current_user.id`.
- [x] Usa el weekly summary como input y valida
      `data_quality.is_ready_for_ai_recommendation`; datos insuficientes → `422`
      (con `missing_data`).
- [x] Genera la recomendación con el fake provider en local/tests (sin llamadas
      reales a Azure OpenAI) y la persiste en base de datos.
- [x] Duplicado para la misma semana → `409`; JSON inválido del provider → `502`
      controlado.
- [x] `GET /recommendations/latest` devuelve la última recomendación del usuario;
      sin recomendaciones → `404`. Un usuario no ve las de otro.
- [x] La recomendación incluye `safety_notes` y el prompt evita consejos médicos
      / diagnósticos.
- [x] Variables `AI_PROVIDER` + `AZURE_OPENAI_*` en `.env.example`; el fake
      provider funciona sin ellas.
- [x] `uv run pytest` pasa (58 tests: los 48 previos + 10 de recomendaciones,
      todos en verde).
- [x] `uv run ruff check .` limpio.
- [x] Sin secretos hardcodeados; todo vía `.env` / `pydantic-settings`.
- [x] Capas separadas (`routes` / `services` / `models` / `schemas` / `db` / `core`),
      con la IA aislada en `services/ai_provider.py`.
- [x] `openai` agregado como dependencia; `AzureOpenAIProvider.generate` usa
      `AsyncAzureOpenAI` para llamar al deployment configurado.
- [x] `AI_PROVIDER=fake` sigue sin requerir credenciales; `AI_PROVIDER=azure`
      exige las 4 variables `AZURE_OPENAI_*` (falla con `503` si falta alguna).
- [x] Se pide `response_format={"type": "json_object"}` y la respuesta se
      valida con `AIGeneratedContent` antes de persistir.
- [x] Timeout de Azure → `503`; error de API/SDK → `502`; JSON inválido → `502`
      (sin exponer detalles internos del SDK ni secretos).
- [x] Tests de `AzureOpenAIProvider` inyectan un cliente fake; ninguna llamada
      real a Azure en la suite.
- [x] `uv run pytest` pasa (66 tests) y `uv run ruff check .` limpio.

## Siguiente paso recomendado

**Bloque 4.1 — Docker Production API Image**: preparará el backend para deploy
real en Azure Container Apps (Dockerfile de producción, variables de entorno,
health check, comando de arranque y documentación local vs cloud).
