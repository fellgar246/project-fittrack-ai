# FitTrack AI — Backend

API backend de FitTrack AI. Bloque actual: **2.4 — Workout Logs API**.

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
      routes/                # capa HTTP: health.py, auth.py, users.py, workout_plans.py, workout_logs.py
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
`workout_logs` en 2.4) ya están generadas y versionadas en `alembic/versions/`; solo
hace falta aplicarlas:

```bash
uv run alembic upgrade head
```

Verificar que las tablas existen:

```bash
docker compose exec db psql -U fittrack -d fittrack -c "\dt"
# debe listar: users, workout_plans, workout_days, exercises, workout_logs, alembic_version

docker compose exec db psql -U fittrack -d fittrack -c "\d workout_logs"
# debe mostrar columnas, FKs a users/exercises, e índices en user_id, exercise_id y performed_at
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
```

Casos de error:
- `POST /auth/register` con un email ya registrado → `409 Conflict`.
- `POST /auth/login` con credenciales inválidas → `401 Unauthorized`.
- `GET /auth/me` sin token, con token inválido/expirado, o con usuario inexistente → `401 Unauthorized`.
- `GET /users/{id}` con un id que no existe → `404 Not Found`.
- `POST /workout-plans` sin token → `401 Unauthorized`; con payload inválido (ej. `day_of_week` fuera de `1-7`) → `422 Unprocessable Entity`.
- `GET /workout-plans/{plan_id}` con un id que no existe o pertenece a otro usuario → `404 Not Found` (mismo mensaje en ambos casos, para no revelar la existencia de planes ajenos).
- `POST /workout-logs` sin token → `401 Unauthorized`; con un `exercise_id` que no existe o pertenece a otro usuario → `404 Exercise not found`; con payload inválido (ej. `sets: 0`) → `422 Unprocessable Entity`.

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
- [x] `uv run pytest` pasa (22 tests: health + auth + workout plans + workout
      logs, todos en verde).
- [x] `uv run ruff check .` limpio.
- [x] Sin secretos hardcodeados; todo vía `.env` / `pydantic-settings`.
- [x] Capas separadas (`routes` / `services` / `models` / `schemas` / `db` / `core`).

## Siguiente paso recomendado

**Bloque 2.5 — Nutrition Logs API**: permitirá registrar macros diarios del
usuario autenticado, siguiendo el mismo patrón de capas (`routes` → `services` →
`models`/`schemas`) y ownership vía `get_current_user`. Junto con los workout
logs de este bloque, será el segundo input clave para las futuras
recomendaciones semanales de IA.
