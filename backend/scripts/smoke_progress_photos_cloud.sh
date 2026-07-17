#!/usr/bin/env bash
# Block 5.10 cloud smoke for progress photos (Azure Blob + PostgreSQL).
# Redacts SAS URLs in output. Requires network access to the deployed API.
set -euo pipefail

BASE_URL="${BASE_URL:-https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-stfittrackaidevdev01}"
CONTAINER="${CONTAINER:-progress-photos}"
RUN_ID="$(date +%s)"
EMAIL="cloud-progress-photo-${RUN_ID}@example.com"
PASSWORD="DemoPass123!"
JPEG="/tmp/block510-smoke-${RUN_ID}.jpg"

python3 - <<'PY' > "$JPEG"
import base64
import sys

sys.stdout.buffer.write(
    base64.b64decode(
        "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof"
        "Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwh"
        "MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAAR"
        "CAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAn/xAAUEAEAAAAAAAAAAAAA"
        "AAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oA"
        "DAMBAAIRAxEAPwCwAA8A/9k="
    )
)
PY
SIZE=$(wc -c < "$JPEG" | tr -d ' ')

redact_url() {
  python3 - <<'PY' "$1"
import sys
from urllib.parse import urlparse, urlunparse

url = sys.argv[1]
parsed = urlparse(url)
print(urlunparse((parsed.scheme, parsed.netloc, parsed.path, "", "<redacted>", "")))
PY
}

register_login() {
  local email="$1"
  curl -s -o /dev/null -X POST "$BASE_URL/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\",\"name\":\"Block510 Smoke\",\"goal\":\"strength\"}"
  TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
  if [[ -z "$TOKEN" ]]; then
    echo "LOGIN_FAILED"
    exit 1
  fi
}

echo "=== HEALTH ==="
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
echo "HEALTH_HTTP=$HEALTH"

echo "=== AUTH ABSENT (expect 401) ==="
NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/upload-requests" \
  -H "Content-Type: application/json" \
  -d '{"captured_at":"2026-07-17","content_type":"image/jpeg","size_bytes":128}')
echo "NO_AUTH_HTTP=$NO_AUTH"

echo "=== INVALID MIME (expect 415) ==="
register_login "$EMAIL"
MIME_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/upload-requests" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"captured_at":"2026-07-17","content_type":"image/svg+xml","size_bytes":128}')
echo "INVALID_MIME_HTTP=$MIME_CODE"

echo "=== OVERSIZED METADATA (expect 413) ==="
OVERSIZE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/upload-requests" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"captured_at":"2026-07-17","content_type":"image/jpeg","size_bytes":6000000}')
echo "OVERSIZE_HTTP=$OVERSIZE"

echo "=== UPLOAD REQUEST ==="
UPLOAD_JSON=$(curl -s -X POST "$BASE_URL/progress-photos/upload-requests" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"captured_at\":\"2026-07-17\",\"content_type\":\"image/jpeg\",\"size_bytes\":$SIZE,\"notes\":\"Cloud smoke fixture\"}")
PHOTO_ID=$(echo "$UPLOAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('photo_id',''))")
UPLOAD_URL=$(echo "$UPLOAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('upload_url',''))")
EXPIRES=$(echo "$UPLOAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('expires_at',''))")
if [[ -z "$PHOTO_ID" || -z "$UPLOAD_URL" ]]; then
  echo "UPLOAD_REQUEST_FAILED"
  exit 1
fi
echo "UPLOAD_REQUEST_OK photo_id=$PHOTO_ID expires_at=$EXPIRES"
echo "UPLOAD_URL=$(redact_url "$UPLOAD_URL")"

echo "=== BLOB PUT (no Authorization header) ==="
PUT_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$UPLOAD_URL" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: image/jpeg" \
  -H "Cache-Control: no-store" \
  --data-binary @"$JPEG")
echo "BLOB_PUT_HTTP=$PUT_CODE size=$SIZE content_type=image/jpeg"
echo "BLOB_PUT_URL=$(redact_url "$UPLOAD_URL")"

echo "=== CONFIRM ==="
CONFIRM1=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/$PHOTO_ID/confirm" \
  -H "Authorization: Bearer $TOKEN")
CONFIRM2=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/$PHOTO_ID/confirm" \
  -H "Authorization: Bearer $TOKEN")
echo "CONFIRM_HTTP_1=$CONFIRM1 CONFIRM_HTTP_2=$CONFIRM2"

echo "=== LIST ==="
LIST_JSON=$(curl -s "$BASE_URL/progress-photos" -H "Authorization: Bearer $TOKEN")
LIST_COUNT=$(echo "$LIST_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
HAS_SAS=$(echo "$LIST_JSON" | python3 -c "import sys,json; s=str(json.load(sys.stdin)); print('yes' if 'sig=' in s or 'upload_url' in s else 'no')")
echo "LIST_COUNT=$LIST_COUNT contains_sas=$HAS_SAS"

echo "=== READ ACCESS ==="
ACCESS_JSON=$(curl -s -X POST "$BASE_URL/progress-photos/$PHOTO_ID/access" \
  -H "Authorization: Bearer $TOKEN")
ACCESS_URL=$(echo "$ACCESS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_url',''))")
ACCESS_EXPIRES=$(echo "$ACCESS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('expires_at',''))")
READ_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ACCESS_URL")
echo "ACCESS_OK expires_at=$ACCESS_EXPIRES READ_BLOB_HTTP=$READ_CODE"
echo "ACCESS_URL=$(redact_url "$ACCESS_URL")"

echo "=== PRIVATE ACCESS WITHOUT SAS ==="
BLOB_PATH=$(python3 - <<'PY' "$UPLOAD_URL"
import sys
from urllib.parse import urlparse

parsed = urlparse(sys.argv[1])
print(parsed.path.lstrip("/"))
PY
)
UNSIGNED="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${BLOB_PATH}"
PRIVATE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$UNSIGNED")
echo "UNSIGNED_URL=$(redact_url "$UNSIGNED")"
echo "PRIVATE_ACCESS_HTTP=$PRIVATE_CODE"

echo "=== USER ISOLATION ==="
EMAIL2="cloud-progress-photo-other-${RUN_ID}@example.com"
register_login "$EMAIL2"
ISO_ACCESS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/$PHOTO_ID/access" \
  -H "Authorization: Bearer $TOKEN")
ISO_CONFIRM=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/$PHOTO_ID/confirm" \
  -H "Authorization: Bearer $TOKEN")
OTHER_LIST=$(curl -s "$BASE_URL/progress-photos" -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "OTHER_USER_ACCESS_HTTP=$ISO_ACCESS OTHER_USER_CONFIRM_HTTP=$ISO_CONFIRM OTHER_LIST_COUNT=$OTHER_LIST"

echo "=== CONFIRM BEFORE PUT (separate user) ==="
EMAIL3="cloud-progress-photo-noput-${RUN_ID}@example.com"
register_login "$EMAIL3"
NOPUT_JSON=$(curl -s -X POST "$BASE_URL/progress-photos/upload-requests" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"captured_at\":\"2026-07-17\",\"content_type\":\"image/jpeg\",\"size_bytes\":$SIZE}")
NOPUT_ID=$(echo "$NOPUT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('photo_id',''))")
NOPUT_CONFIRM=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$BASE_URL/progress-photos/$NOPUT_ID/confirm" \
  -H "Authorization: Bearer $TOKEN")
NOPUT_LIST=$(curl -s "$BASE_URL/progress-photos" -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "CONFIRM_WITHOUT_PUT_HTTP=$NOPUT_CONFIRM NOPUT_LIST_COUNT=$NOPUT_LIST"

rm -f "$JPEG"
echo "=== CLOUD SMOKE COMPLETE ==="
