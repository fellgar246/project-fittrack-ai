# Cloud API Smoke Test

> **Portfolio demo:** For architecture, tradeoffs, interview narrative, and teardown notes, see
> [Portfolio Demo](./portfolio-demo.md).

## Block 4.21 — Cloud API Functional Smoke Test

Status: **completed**.

Execution date: **2026-07-09T14:11:25Z**.

Demo user: `cloud-smoke-20260709081125@example.com`.

## Goal

Validate that the FitTrack AI API running on Azure Container Apps works end-to-end with Azure
PostgreSQL and Key Vault-backed secrets — beyond `/health` and auth.

## Validated flow

```text
Azure Container Apps
→ Managed Identity
→ Key Vault DATABASE-URL
→ Azure PostgreSQL
→ application endpoints (auth, CRUD, weekly summary, FakeAIProvider)
```

## API URL

```text
https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

## Validated endpoints

| Area         | Endpoint                        | Result       |
| ------------ | ------------------------------- | ------------ |
| Health       | GET /health                     | HTTP 200     |
| Auth         | POST /auth/register             | HTTP 201     |
| Auth         | POST /auth/login                | HTTP 200     |
| User         | GET /auth/me                    | HTTP 200     |
| Measurements | POST /measurements              | HTTP 201     |
| Measurements | GET /measurements               | HTTP 200     |
| Measurements | GET /measurements/progress      | HTTP 200     |
| Nutrition    | POST /nutrition-logs (×3)       | HTTP 201     |
| Nutrition    | GET /nutrition-logs             | HTTP 200     |
| Nutrition    | GET /nutrition-logs/summary     | HTTP 200     |
| Workouts     | POST /workout-plans             | HTTP 201     |
| Workouts     | GET /workout-plans              | HTTP 200     |
| Workouts     | GET /workout-plans/{id}         | HTTP 200     |
| Workouts     | POST /workout-logs              | HTTP 201     |
| Workouts     | GET /workout-logs               | HTTP 200     |
| Workouts     | GET /workout-logs/summary       | HTTP 200     |
| Weekly       | GET /weekly-summary             | HTTP 200     |
| AI           | POST /recommendations/weekly    | HTTP 201     |
| AI           | GET /recommendations/latest     | HTTP 200     |

Weekly summary readiness: `is_ready_for_ai_recommendation=true`, `missing_data=[]`.

## Payload adjustments vs original plan

The backend uses different paths and field names than the conceptual plan:

| Original (plan)              | Actual (backend)                          |
| ---------------------------- | ----------------------------------------- |
| GET /users/me                | GET /auth/me                              |
| /body-measurements           | /measurements                             |
| full_name                    | name                                      |
| weight_kg, waist_cm          | weight, waist, body_fat_estimate          |
| protein_g, carbs_g, fat_g    | protein, carbs, fats                      |
| days[].name, day_order       | days[].title, day_of_week                 |
| sets, reps (string)          | target_sets, target_reps on exercises     |
| date, sets_completed         | performed_at, sets, reps on workout logs  |

## Repeatable smoke test

```bash
API_URL="https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io"
TEST_RUN_ID="$(date +%Y%m%d%H%M%S)"
TEST_EMAIL="cloud-smoke-${TEST_RUN_ID}@example.com"
TEST_PASSWORD="DevOnlyTest123!"

# 1. Health
curl -i "$API_URL/health"

# 2. Register
curl -i -X POST "$API_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${TEST_EMAIL}\",\"name\":\"Cloud Smoke Test\",\"password\":\"${TEST_PASSWORD}\",\"goal\":\"body recomposition\"}"

# 3. Login — store token locally, never print or document it
curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}" > /tmp/login_response.json
ACCESS_TOKEN=$(python3 -c 'import json; print(json.load(open("/tmp/login_response.json")).get("access_token",""))')
test -n "$ACCESS_TOKEN" && echo "Token captured safely"

# 4. Current user
curl -i "$API_URL/auth/me" -H "Authorization: Bearer $ACCESS_TOKEN"

TODAY=$(date +%F)
DAY_1=$(python3 -c 'from datetime import date, timedelta; print((date.today()-timedelta(days=1)).isoformat())')
DAY_2=$(python3 -c 'from datetime import date, timedelta; print((date.today()-timedelta(days=2)).isoformat())')
WEEK_START=$(python3 -c 'from datetime import date, timedelta; t=date.today(); print((t-timedelta(days=t.weekday())).isoformat())')
PERFORMED_AT=$(python3 -c 'from datetime import datetime; print(datetime.now().replace(microsecond=0).isoformat())')

# 5. Measurement
curl -i -X POST "$API_URL/measurements" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"date\":\"${TODAY}\",\"weight\":70.5,\"waist\":80.0,\"body_fat_estimate\":24.5,\"notes\":\"Cloud smoke test measurement\"}"

# 6. Nutrition (3 distinct dates for weekly summary readiness)
for D in "$TODAY" "$DAY_1" "$DAY_2"; do
  curl -i -X POST "$API_URL/nutrition-logs" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "{\"date\":\"${D}\",\"calories\":2100,\"protein\":120,\"carbs\":250,\"fats\":60,\"notes\":\"Cloud smoke test nutrition log\"}"
done

# 7. Workout plan
curl -s -X POST "$API_URL/workout-plans" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Cloud Smoke Test Plan",
    "goal": "body recomposition",
    "active": true,
    "days": [
      {
        "day_of_week": 1,
        "title": "Upper A",
        "exercises": [
          {"name": "Push-ups", "muscle_group": "chest", "target_sets": 3, "target_reps": "8-12"}
        ]
      },
      {
        "day_of_week": 2,
        "title": "Lower A",
        "exercises": [
          {"name": "Bulgarian split squat", "muscle_group": "legs", "target_sets": 3, "target_reps": "8-10"}
        ]
      }
    ]
  }' > /tmp/plan_response.json

PLAN_ID=$(python3 -c 'import json; print(json.load(open("/tmp/plan_response.json")).get("id",""))')
curl -s "$API_URL/workout-plans/${PLAN_ID}" -H "Authorization: Bearer $ACCESS_TOKEN" > /tmp/plan_detail.json

EXERCISE_ID=$(python3 -c 'import json; d=json.load(open("/tmp/plan_detail.json"));
for day in d.get("days",[]):
  for ex in day.get("exercises",[]):
    if ex.get("id"): print(ex["id"]); raise SystemExit')

# 8. Workout log
curl -i -X POST "$API_URL/workout-logs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"exercise_id\":\"${EXERCISE_ID}\",\"performed_at\":\"${PERFORMED_AT}\",\"sets\":3,\"reps\":10,\"weight\":0,\"notes\":\"Cloud smoke test workout log\"}"

# 9. Weekly summary + AI recommendation (FakeAIProvider)
curl -i "$API_URL/weekly-summary?week_start=${WEEK_START}" -H "Authorization: Bearer $ACCESS_TOKEN"

curl -i -X POST "$API_URL/recommendations/weekly" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d "{\"week_start\":\"${WEEK_START}\"}"

curl -i "$API_URL/recommendations/latest" -H "Authorization: Bearer $ACCESS_TOKEN"
```

## PostgreSQL persistence check

Use a temporary firewall rule and load `DATABASE_URL` from Key Vault without printing it:

```bash
PUBLIC_IP=$(curl -s https://api.ipify.org)

az postgres flexible-server firewall-rule create \
  --resource-group rg-fittrack-ai-dev \
  --server-name psql-fittrack-ai-pg-dev01 \
  --name temp-local-smoke-verify \
  --start-ip-address "$PUBLIC_IP" \
  --end-ip-address "$PUBLIC_IP"

export DATABASE_URL="$(az keyvault secret show \
  --vault-name kvfittrackaidevdev01 --name DATABASE-URL --query value -o tsv)"
test -n "$DATABASE_URL" && echo "DATABASE_URL loaded"

# Run row-count queries for the demo user email (see Block 4.21 infra README)

az postgres flexible-server firewall-rule delete \
  --resource-group rg-fittrack-ai-dev \
  --server-name psql-fittrack-ai-pg-dev01 \
  --name temp-local-smoke-verify --yes
```

Block 4.21 verified counts:

```text
body_measurements_count=1
nutrition_logs_count=3
workout_plans_count=1
workout_logs_count=1
ai_recommendations_count=1
```

## Container App logs

```bash
az containerapp logs show \
  --name ca-fittrack-ai-api-dev \
  --resource-group rg-fittrack-ai-dev \
  --tail 150
```

No critical errors observed (DB timeout, Key Vault denied, SQLAlchemy, provider failures).
One `GET /` → HTTP 404 is expected (no root route).

## Terraform and backend validation

```bash
cd infra/terraform/azure/environments/dev
terraform plan -var-file="terraform.postgres.example.tfvars"
# Expected: No changes

cd backend
uv run ruff check .
uv run pytest
# Expected: All checks passed; 66 passed
```

## Important

- No secrets were exposed.
- Bearer token was not documented.
- `DATABASE_URL` was not printed.
- Alembic was not re-run.
- Terraform remained unchanged.
- Final Terraform plan remained clean.
- The AI provider used was **FakeAIProvider**, not Azure OpenAI.
- No `terraform apply`, `docker build`, or `docker push` was executed.

## Next step

**Block 4.22 — Portfolio Demo Documentation Polish** — **completed**. See
[Portfolio Demo](./portfolio-demo.md) for architecture, tradeoffs, interview narrative, and
teardown notes.

**Block 4.23 — Azure OpenAI Runtime Verification** — **completed**. Real Azure OpenAI validated
in cloud (`AI_PROVIDER=azure`, deployment `fittrack-gpt-5-mini`, image `block-4.23-amd64`).
Demo user: `cloud-azure-openai-20260709220923@example.com`. See
[Azure OpenAI Runtime](./azure-openai-runtime.md).

**Block 4.24 — Final Portfolio Release** — next.
