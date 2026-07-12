# FitTrack AI — Mobile

Flutter mobile client for the FitTrack AI cloud-native fitness platform.

## Overview

This folder contains the FitTrack AI mobile application. Block 5.2 adds a real HTTP client,
authentication against the cloud API, secure JWT storage, session restoration, protected routes,
and functional login/register screens.

**Application ID:** `com.fittrackai.fittrack_ai`

## Requirements

- Flutter SDK 3.13+
- Dart SDK 3.1+
- Xcode for iOS / macOS builds
- Android Studio / Android SDK for Android builds
- CocoaPods for iOS dependencies

## Install

```bash
cd mobile
flutter pub get
```

## Authentication status

- Dio HTTP client with centralized configuration and error mapping
- Secure JWT storage via `flutter_secure_storage`
- Register, login, session restore, `/auth/me`, and logout
- Riverpod auth state and go_router route guards
- Bootstrap session restoration on app start

## Run against cloud API

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
```

## Run against local API on iOS Simulator

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Run against local API on Android Emulator

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Security notes

- JWT stored in platform secure storage (`fittrack_access_token`)
- Passwords are never persisted
- Authorization headers and sensitive fields are redacted from development logs
- No refresh token flow (backend does not support refresh tokens)

## Testing

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Architecture

```text
lib/
├── app/          # App shell, router, theme
├── core/         # Config, network, errors, storage, validation
├── features/     # Auth, bootstrap, dashboard
└── shared/       # Reusable widgets
```

## Dependencies

- `flutter_riverpod` — auth and configuration state
- `go_router` — declarative navigation with auth guards
- `dio` — HTTP client
- `flutter_secure_storage` — secure JWT persistence

## Current scope

- App foundation
- Theme (light/dark)
- Navigation (`/`, `/login`, `/register`, `/dashboard`)
- Environment configuration via `--dart-define`
- Real authentication flow against FastAPI
- Bootstrap session restoration
- Login and register screens
- Authenticated dashboard placeholder with logout
- Unit and widget tests (56 tests)

## Deferred

- Functional fitness dashboard
- Measurements, nutrition, workouts
- Azure Blob Storage
- Observability

## Next block

```text
Block 5.3 — Mobile Dashboard
```
