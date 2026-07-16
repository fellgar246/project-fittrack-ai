#!/usr/bin/env bash
# Local smoke for Block 5.8 progress photos using the fake storage provider.
# Requires PostgreSQL reachable via DATABASE_URL and the API running locally.
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
EMAIL="block58-smoke-$(date +%s)@example.com"
PASSWORD="DemoPass123!"

register() {
  curl -s -X POST "$BASE_URL/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"name\":\"Block58 Smoke\",\"goal\":\"strength\"}" >/dev/null
}

login() {
  TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
  if [[ -z "$TOKEN" ]]; then
    echo "LOGIN_FAILED"
    exit 1
  fi
  echo "LOGIN_OK"
}

request_upload() {
  RESP=$(curl -s -X POST "$BASE_URL/progress-photos/upload-requests" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"captured_at":"2026-07-15","content_type":"image/jpeg","size_bytes":128,"notes":"fixture"}')
  PHOTO_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('photo_id',''))")
  UPLOAD_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('upload_url',''))")
  if [[ -z "$PHOTO_ID" ]]; then
    echo "UPLOAD_REQUEST_FAILED"
    exit 1
  fi
  echo "UPLOAD_REQUEST_OK photo_id=$PHOTO_ID"
  echo "UPLOAD_URL=https://<account>.blob.core.windows.net/<container>/<blob>?<redacted>"
}

confirm() {
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$BASE_URL/progress-photos/$PHOTO_ID/confirm" \
    -H "Authorization: Bearer $TOKEN")
  echo "CONFIRM_HTTP=$CODE"
}

list_photos() {
  COUNT=$(curl -s "$BASE_URL/progress-photos" -H "Authorization: Bearer $TOKEN" \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  echo "LIST_COUNT=$COUNT"
}

access_url() {
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$BASE_URL/progress-photos/$PHOTO_ID/access" \
    -H "Authorization: Bearer $TOKEN")
  echo "ACCESS_HTTP=$CODE"
}

register
login
request_upload
confirm
list_photos
access_url
echo "SMOKE_NOTE=fake provider requires simulated blob upload before confirm succeeds"
