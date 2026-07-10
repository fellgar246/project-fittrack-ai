# FitTrack AI — Flutter Mobile Transition

## Decision

The original mobile option was React Native / Expo. The project will now move forward with
Flutter for the mobile client.

## Reason

Flutter was selected to build a polished cross-platform mobile experience and strengthen the
mobile portfolio angle while keeping the existing backend/cloud architecture unchanged.

## What does not change

- FastAPI backend
- PostgreSQL database
- Azure Container Apps deployment
- Azure OpenAI recommendation flow
- Terraform infrastructure
- Docker production image
- Key Vault secret management

## Mobile phase goal

Build a Flutter app that consumes the existing cloud API and demonstrates the end-to-end product
experience.

## Planned mobile blocks

```text
Block 5.1 — Flutter Mobile App Foundation
Block 5.2 — Flutter API Client + Auth
Block 5.3 — Mobile Dashboard
Block 5.4 — Measurements Flow
Block 5.5 — Nutrition Logs Flow
Block 5.6 — Workout Flow
Block 5.7 — Weekly Summary + AI Recommendation
Block 5.8 — Progress Photos + Azure Blob Storage
Block 5.9 — Observability Polish
Block 5.10 — Final Portfolio Release
```

## MVP mobile scope

The first mobile MVP should include:

- Login
- Register
- Dashboard
- Measurements
- Nutrition logs
- Workout logs
- Weekly summary
- Latest AI recommendation

## Deferred mobile/cloud scope

- Progress photos with Azure Blob Storage
- Push notifications
- Offline mode
- Advanced charts
- App Store / Play Store release
- Full production hardening
