# FitTrack AI — Mobile

Flutter mobile client for the FitTrack AI cloud-native fitness platform.

## Overview

This folder contains the FitTrack AI mobile application. Block 5.1 establishes the
foundation: feature-first structure, environment configuration, centralized theme,
declarative navigation, and placeholder screens for upcoming auth and fitness flows.

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

## Validation

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Architecture

```text
lib/
├── app/          # App shell, router, theme
├── core/         # Config, constants, errors, API paths
├── features/     # Feature-first screens
└── shared/       # Reusable widgets
```

## Dependencies

- `flutter_riverpod` — app configuration provider
- `go_router` — declarative navigation

HTTP client, secure storage, and auth state are deferred to Block 5.2.

## Current scope

- App foundation
- Theme (light/dark)
- Navigation (`/`, `/login`, `/dashboard`)
- Environment configuration via `--dart-define`
- Bootstrap, login, and dashboard placeholder screens
- Unit and widget tests

## Deferred

- Real auth
- API client
- Secure token storage
- Fitness features
- Azure Blob Storage
- Observability

## Next block

```text
Block 5.2 — Flutter API Client + Auth
```
