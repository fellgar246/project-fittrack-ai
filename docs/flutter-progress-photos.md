# Flutter Progress Photos Flow (Block 5.9)

## Purpose

Block 5.9 adds authenticated progress photo upload and gallery to the FitTrack AI Flutter client.
Users select an image from the device gallery, preview it, set a capture date and optional notes,
upload directly to Azure Blob Storage via a short-lived SAS, confirm with the backend, and browse
private photos with on-demand read access URLs.

Backend storage, PostgreSQL metadata, Terraform, and the API contract were delivered in Block 5.8.
See [docs/progress-photos-architecture.md](progress-photos-architecture.md) for the full backend
design.

## Architecture

```text
ProgressPhotosScreen / CreateProgressPhotoScreen / ProgressPhotoDetailScreen
→ ProgressPhotosController / CreateProgressPhotoController
→ ProgressPhotosRepository
→ ProgressPhotosApi (authenticated) + ProgressPhotoUploadClient (blob only)
→ FastAPI + Azure Blob Storage
```

Upload flow:

```text
Gallery picker + local validation
→ POST /progress-photos/upload-requests (ApiClient / JWT)
→ PUT upload_url (ProgressPhotoUploadClient — no Authorization header)
→ POST /progress-photos/{photo_id}/confirm (ApiClient / JWT)
→ pop(true) → gallery refresh
```

Gallery read flow:

```text
GET /progress-photos (metadata only)
→ POST /progress-photos/{photo_id}/access (per image, on demand)
→ Image.network with in-memory URL cache until expiry
```

## Endpoints consumed

| Operation | Method | Path | Auth | Notes |
|-----------|--------|------|------|-------|
| Create upload authorization | `POST` | `/progress-photos/upload-requests` | Bearer | Body: `captured_at`, `content_type`, `size_bytes`, optional `notes`. Returns `photo_id`, `upload_url`, `expires_at`, `required_headers`. |
| Confirm upload | `POST` | `/progress-photos/{photo_id}/confirm` | Bearer | No body. Idempotent when already `active`. Returns `ProgressPhotoRead`. |
| List metadata | `GET` | `/progress-photos` | Bearer | Active photos only. Ordered `captured_at DESC`, `created_at DESC`. No SAS in response. |
| Request read access | `POST` | `/progress-photos/{photo_id}/access` | Bearer | Returns `photo_id`, `access_url`, `expires_at`. |

## Constraints (backend-aligned)

Defined in `ProgressPhotoConstraints` — keep in sync with backend defaults:

| Constraint | Value |
|------------|-------|
| Allowed MIME | `image/jpeg`, `image/png`, `image/webp` |
| Max size | `5 * 1024 * 1024` bytes (5 MiB) |
| Max notes length | 2000 characters |
| Upload/read SAS TTL | 300 seconds |
| Access renewal safety window | 30 seconds before `expires_at` |

Required upload headers (from backend authorization response):

- `Content-Type` — declared MIME
- `x-ms-blob-type: BlockBlob`
- `Cache-Control: no-store`

## Data models

Manual Dart models (no code generation):

- `ProgressPhoto` — list/detail metadata; no persistent image URL
- `CreateProgressPhotoUploadRequest` — `captured_at` (`YYYY-MM-DD`), `content_type`, `size_bytes`, optional `notes`
- `ProgressPhotoUploadAuthorization` — `photo_id`, `upload_url`, `expires_at`, `required_headers`
- `ProgressPhotoAccessAuthorization` — `photo_id`, `access_url`, `expires_at`

## Two HTTP clients (security)

### Backend API — authenticated

Uses the existing `ApiClient` / Dio with JWT bearer injection, session handling, and redacted
logging. All four progress photo endpoints use this client.

### Blob upload — isolated

`ProgressPhotoUploadClient` uses a **separate** `Dio` instance:

- No bearer or session interceptors
- No backend base URL
- PUT to the exact SAS `upload_url` from the authorization response
- Only headers from `required_headers` plus Dio transport defaults
- Connect 15s, send 120s, receive 30s (sufficient for 5 MiB uploads)

Tests assert explicitly that the `Authorization` header is **absent** on blob PUT requests.

## SAS redaction

`redactSignedUrl()` in `lib/core/network/redact_signed_url.dart` strips query strings from blob URLs
for logs, exceptions, and debug output:

```text
https://account.blob.core.windows.net/container/blob?sv=...&sig=...
→ https://account.blob.core.windows.net/container/blob?<redacted>
```

SAS URLs are never shown in UI, persisted to secure storage, or written to preferences.

## Image selection and validation

- Gallery only via `image_picker` 1.0.8 (no camera in this block)
- After pick: verify file exists, read bytes, detect MIME via magic bytes + `mime` package
- Reject unsupported MIME or size above limit before calling the backend
- Preview with option to replace or clear selection
- Default capture date: today; editable via date picker; no future dates

## Upload controller states

`CreateProgressPhotoState` tracks:

- `idle`, `selecting`, `ready`, `requestingAuthorization`, `uploading`, `confirming`, `success`, `failure`
- `awaitingConfirmRetry` when PUT succeeded but confirm failed or timed out

Recovery:

- **Confirm failed after successful PUT** — retain `photo_id`, offer "Retry confirmation"; do not repeat PUT
- **Upload SAS expired (403)** — user message; start a new upload request (new `photo_id`; prior pending record remains for backend cleanup)
- **Confirm timeout** — treat as uncertain; confirm is idempotent and safe to retry

## Gallery and access cache

`ProgressPhotoAccessCache` stores read URLs in memory only:

- Key: `photo_id`
- Value: `access_url`, `expires_at`
- Renew when `expires_at <= now + 30s`
- Invalidate on image load error (e.g. expired SAS) and retry once

Partial failures: a single photo failing to obtain an access URL does not fail the entire gallery.

## Routes

Protected routes (auth guard):

| Route | Screen |
|-------|--------|
| `/progress-photos` | Gallery |
| `/progress-photos/new` | Create / upload |
| `/progress-photos/:photoId` | Detail |

Entry: Dashboard quick action "Progress photos".

Detail navigation passes photo metadata via route `extra` when coming from the gallery; there is no
`GET /progress-photos/{id}` endpoint.

## Native permissions

### iOS

`NSPhotoLibraryUsageDescription` in `Info.plist`:

```text
FitTrack AI uses your photo library so you can add private progress photos.
```

No camera or microphone permissions.

### Android

Uses the modern Photo Picker where supported. Broad storage permissions are explicitly removed from
the merged manifest via `tools:node="remove"` for `READ_MEDIA_*` and legacy external storage
permissions not required by `image_picker` 1.0.8 on API 33+.

## Error handling

### Backend (`ApiClient`)

- `401` — central auth logout (session expired)
- `404`, `409`, `413`, `415`, `422`, `502`, `503` — mapped via existing error mapper

### Blob (`ProgressPhotoUploadClient`)

| Status / condition | User message |
|--------------------|--------------|
| 403 | Upload authorization expired or invalid |
| 404 | Upload destination unavailable |
| 409 | Blob state conflict |
| Timeout | Upload timed out |
| Connection error | Could not connect to storage |
| Other 4xx | Upload rejected |
| 5xx | Storage temporarily unavailable |

Blob `403` does **not** trigger logout.

## Privacy

- Progress photos are private to the authenticated account (UI copy only; not end-to-end encryption)
- No image bytes, SAS URLs, or notes in logs, analytics, or persistent storage
- HTTP/image cache may retain bytes after URL expiry — documented limitation; no custom encrypted cache

## Tests

Automated coverage under `mobile/test/features/progress_photos/`:

- Model serialization and defensive parsing
- API client paths and payloads (mock Dio)
- Blob client: PUT headers, progress, no bearer, error mapping, SAS redaction
- Repository: full lifecycle, confirm retry without repeat PUT, access cache
- Controllers: upload states, double-submit guard, gallery partial failures
- Widget tests: gallery loading/empty/loaded, privacy copy, add action, pull-to-refresh

Fixtures use small generated PNG bytes — no personal photos or real SAS tokens.

Total project test count after Block 5.9: **319** (was 289).

## Local development

Works against the backend with `FakeProgressPhotoStorage` (Block 5.8) without Azure cloud deploy:

```bash
# Backend with fake storage
cd backend
uv run uvicorn app.main:app --reload

# Flutter (iOS Simulator example)
cd mobile
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Cloud smoke

Validated in Block 5.10 — see [progress-photos-release-validation.md](progress-photos-release-validation.md).

Automated Flutter cloud E2E:

```bash
flutter test test/integration/cloud_progress_photos_e2e_test.dart \
  --dart-define=RUN_CLOUD_E2E=true \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

Interactive macOS/iOS checklist (manual): register/login → gallery → upload demo image → confirm → detail → refresh → re-login; inspect logs for absence of JWT and full SAS URLs.

## Limitations (this block)

- Gallery picker only (no camera, crop, compression, filters, edit, delete, share, download)
- No before/after comparison or offline gallery
- No persistent access URL cache or background upload/recovery
- Orphan blobs possible if app closes after PUT but before confirm (backend cleanup deferred)
- No thumbnails server-side

## Related docs

- [progress-photos-architecture.md](progress-photos-architecture.md) — backend design and Block 5.8
- [azure-blob-progress-photos.md](azure-blob-progress-photos.md) — Azure storage configuration
