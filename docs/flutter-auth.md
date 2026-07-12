# Flutter Mobile Authentication

Architecture and behavior for Block 5.2 authentication in the FitTrack AI Flutter client.

## Architecture

```text
Flutter UI
  → AuthController (Riverpod)
  → AuthRepository
  → AuthApi
  → ApiClient / Dio
  → FastAPI
```

Token flow:

```text
Login / Register
  → access_token
  → secure storage (fittrack_access_token)
  → Authorization interceptor
  → GET /auth/me
```

## Backend contracts used

| Endpoint | Request | Response | Status |
|----------|---------|----------|--------|
| `POST /auth/register` | `{email, name, password, goal?}` | `{id, email, name, goal}` | 201 |
| `POST /auth/login` | `{email, password}` | `{access_token, token_type}` | 200 |
| `GET /auth/me` | Bearer JWT | `{id, email, name, goal}` | 200 |

Register does **not** return a token. The mobile client registers, then performs an automatic
login with the same credentials.

## Session restore

```text
read secure token
  → if missing: unauthenticated
  → GET /auth/me
    → 200: authenticated
    → 401: delete token, unauthenticated
    → network/timeout: keep token, show bootstrap retry
```

A network error during restore does **not** invalidate a potentially valid token.

## Error handling

Dio and HTTP errors are mapped to typed exceptions:

- connection/timeout → `NetworkException` / `TimeoutApiException`
- 401 → `UnauthorizedException`
- 409 → `ConflictException`
- 422 → `ValidationException` (FastAPI list `detail` supported)
- 500+ → `ServerException`

Login credential failures and protected-route 401s are handled differently at the UI layer.

## Security

- JWT in platform secure storage only
- Password never persisted
- Development logs redact `Authorization`, `password`, `access_token`, and `token`
- No refresh token (backend uses HS256 access tokens with 60-minute expiry)
- No OAuth, biometrics, or certificate pinning in this block

## Navigation guards

- Bootstrap (`/`) during initial restore or recoverable network failure
- Unauthenticated users redirected from `/dashboard` to `/login`
- Authenticated users redirected from `/`, `/login`, `/register` to `/dashboard`
- Logout clears token and returns to `/login`

## Limitations

- No biometrics
- No refresh token or silent re-auth
- No OAuth / social login
- No offline login
- No production certificate pinning
- macOS used for smoke validation when mobile simulators are unavailable

## Smoke test (cloud API)

Validated against the dev Container Apps URL:

- health: HTTP 200
- register: HTTP 201
- login: HTTP 200
- me: HTTP 200
- invalid login: HTTP 401 with `Invalid email or password`
- session restore and logout: covered by unit/widget tests; manual macOS run uses same contract
