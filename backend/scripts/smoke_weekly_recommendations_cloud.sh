#!/usr/bin/env bash
# Block 5.10 / 5.7 cloud smoke for weekly summary + Azure OpenAI recommendations.
set -euo pipefail

BASE_URL="${BASE_URL:-https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io}"
RUN_ID="$(date +%s)"
PASSWORD="DemoPass123!"
WEEK_START=$(python3 -c 'from datetime import date, timedelta; t=date.today(); print((t-timedelta(days=t.weekday())).isoformat())')
TODAY=$(date +%F)
DAY_1=$(python3 -c 'from datetime import date, timedelta; print((date.today()-timedelta(days=1)).isoformat())')
DAY_2=$(python3 -c 'from datetime import date, timedelta; print((date.today()-timedelta(days=2)).isoformat())')
PERFORMED_AT=$(python3 -c 'from datetime import datetime; print(datetime.now().replace(microsecond=0).isoformat())')

auth() {
  local email="$1"
  curl -s -o /dev/null -X POST "$BASE_URL/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\",\"name\":\"Block57 Smoke\",\"goal\":\"strength\"}"
  TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
  if [[ -z "$TOKEN" ]]; then
    echo "LOGIN_FAILED email=$email"
    exit 1
  fi
}

echo "=== NOT-READY USER ==="
EMAIL_NOT_READY="block57-not-ready-${RUN_ID}@example.com"
auth "$EMAIL_NOT_READY"
SUMMARY=$(curl -s "$BASE_URL/weekly-summary?week_start=$WEEK_START" -H "Authorization: Bearer $TOKEN")
READY=$(echo "$SUMMARY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data_quality',{}).get('is_ready_for_ai_recommendation', 'missing'))")
MISSING=$(echo "$SUMMARY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(d.get('data_quality',{}).get('missing_data',[])))")
echo "IS_READY=$READY missing=$MISSING"
REC_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/recommendations/weekly" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"week_start\":\"$WEEK_START\"}")
echo "GENERATE_WHEN_NOT_READY_HTTP=$REC_CODE (expect 422 or 400)"

echo "=== READY USER ==="
EMAIL_READY="block57-ready-${RUN_ID}@example.com"
auth "$EMAIL_READY"
curl -s -o /dev/null -X POST "$BASE_URL/measurements" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"date\":\"$TODAY\",\"weight\":70.5,\"waist\":80.0,\"body_fat_estimate\":24.5,\"notes\":\"smoke\"}"
for D in "$TODAY" "$DAY_1" "$DAY_2"; do
  curl -s -o /dev/null -X POST "$BASE_URL/nutrition-logs" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"date\":\"$D\",\"calories\":2100,\"protein\":120,\"carbs\":250,\"fats\":60,\"notes\":\"smoke\"}"
done
PLAN_JSON=$(curl -s -X POST "$BASE_URL/workout-plans" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Block57 Smoke Plan","goal":"strength","active":true,"days":[{"day_of_week":1,"title":"Upper","exercises":[{"name":"Push-ups","muscle_group":"chest","target_sets":3,"target_reps":"8-12"}]}]}')
PLAN_ID=$(echo "$PLAN_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")
DETAIL=$(curl -s "$BASE_URL/workout-plans/$PLAN_ID" -H "Authorization: Bearer $TOKEN")
EXERCISE_ID=$(echo "$DETAIL" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['days'][0]['exercises'][0]['id'])")
curl -s -o /dev/null -X POST "$BASE_URL/workout-logs" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"exercise_id\":\"$EXERCISE_ID\",\"performed_at\":\"$PERFORMED_AT\",\"sets\":3,\"reps\":10,\"weight\":0,\"notes\":\"smoke\"}"

SUMMARY2=$(curl -s "$BASE_URL/weekly-summary?week_start=$WEEK_START" -H "Authorization: Bearer $TOKEN")
READY2=$(echo "$SUMMARY2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data_quality',{}).get('is_ready_for_ai_recommendation'))")
echo "IS_READY=$READY2"

echo "=== AZURE OPENAI RECOMMENDATION ==="
REC_JSON=$(curl -s -X POST "$BASE_URL/recommendations/weekly" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"week_start\":\"$WEEK_START\"}")
REC_HTTP=$(echo "$REC_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('id') or d.get('recommendation') else 'error')")
HAS_TEXT=$(echo "$REC_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); t=d.get('recommendation',''); print('yes' if len(t)>20 else 'no')")
echo "RECOMMENDATION_RESULT=$REC_HTTP has_text=$HAS_TEXT"

LATEST=$(curl -s "$BASE_URL/recommendations/latest" -H "Authorization: Bearer $TOKEN")
LATEST_OK=$(echo "$LATEST" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if d.get('recommendation') else 'no')")
echo "LATEST_PERSISTED=$LATEST_OK"

echo "=== BLOCK 5.7 CLOUD SMOKE COMPLETE ==="
