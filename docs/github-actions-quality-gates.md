# FitTrack AI — GitHub Actions Quality Gates (Block 6.1)

**Block:** 6.1  
**Scope:** Backend and Flutter pull-request quality gates only — no deployment, no Azure credentials, no Terraform.

---

## 1. Objective

Automated CI validates the FastAPI backend and Flutter mobile app on every relevant pull request
and push to `main`. The goal is to detect regressions before merge without touching Azure,
Docker release, or Terraform apply.

Expected flow:

```text
Pull request / push to main
  → Backend quality (if backend/** changed)
  → Flutter quality (if mobile/** changed)
  → clear pass/fail status on GitHub
```

Full reference: [`.github/workflows/backend-ci.yml`](../.github/workflows/backend-ci.yml) and
[`.github/workflows/flutter-ci.yml`](../.github/workflows/flutter-ci.yml).

---

## 2. Workflows

Two separate workflows (Option B — clear ownership and path filtering):

| Workflow file | Display name | Job name (check name) |
|---------------|--------------|------------------------|
| `backend-ci.yml` | Backend CI | **Backend quality** |
| `flutter-ci.yml` | Flutter CI | **Flutter quality** |

Use these check names when configuring branch protection on `main`.

---

## 3. Triggers

Both workflows run on:

- `pull_request` (with path filters)
- `push` to `main` (with path filters)
- `workflow_dispatch` (manual re-run)

No `pull_request_target`. No scheduled runs.

---

## 4. Path filters

### Backend CI

Runs when these paths change:

```text
backend/**
.github/workflows/backend-ci.yml
```

### Flutter CI

Runs when these paths change:

```text
mobile/**
.github/workflows/flutter-ci.yml
```

### Caveat

PRs that change **only** root docs, Terraform, or infra files may **not** trigger either workflow.
When enabling branch protection, confirm path coverage or open a test PR that touches both stacks
before requiring both checks globally.

---

## 5. Permissions

```yaml
permissions:
  contents: read
```

No `id-token`, `packages: write`, `pull-requests: write`, or `deployments: write`. Workflows are
safe for pull requests from forks — no GitHub secrets are used.

---

## 6. Concurrency

Each workflow cancels stale runs for the same ref:

```yaml
concurrency:
  group: backend-ci-${{ github.workflow }}-${{ github.ref }}   # or flutter-ci-...
  cancel-in-progress: true
```

Groups are distinct per workflow so backend and Flutter runs do not cancel each other.

---

## 7. Backend job

**Runner:** `ubuntu-latest`  
**Timeout:** 15 minutes  
**Working directory:** `backend/`

Steps (in order):

1. Checkout
2. Python 3.11 (`actions/setup-python@v5`)
3. uv with cache (`astral-sh/setup-uv@v5`, `enable-cache: true`)
4. `uv sync --frozen`
5. PostgreSQL readiness (`pg_isready`)
6. `uv run alembic upgrade head`
7. `uv run alembic current`
8. `uv run ruff check .`
9. `uv run pytest`

---

## 8. PostgreSQL service

Ephemeral PostgreSQL 16 service container (matches local `docker-compose.yml` and Azure Flexible
Server major version):

| Setting | Value |
|---------|-------|
| Image | `postgres:16` |
| User | `fittrack` |
| Password | `fittrack` |
| Database | `fittrack_test` |
| Port | `5432` (mapped to localhost) |

Health check: `pg_isready -U fittrack -d fittrack_test` (service + explicit step).

Credentials are fictitious and CI-only. No Azure database is used.

---

## 9. Backend test environment

Job-level environment variables:

| Variable | CI value | Notes |
|----------|----------|-------|
| `DATABASE_URL` | `postgresql+psycopg://fittrack:fittrack@localhost:5432/fittrack_test` | Async driver via psycopg3 |
| `JWT_SECRET_KEY` | `ci-only-not-a-real-secret` | Required by `Settings`; not a GitHub secret |
| `AI_PROVIDER` | `fake` | No Azure OpenAI |
| `PROGRESS_PHOTO_STORAGE_PROVIDER` | `fake` | No Azure Blob |

No `APP_ENV` — backend `Settings` does not define it.

---

## 10. Fake providers

- **`AI_PROVIDER=fake`** — deterministic `FakeAIProvider`; no network or Azure credentials.
- **`PROGRESS_PHOTO_STORAGE_PROVIDER=fake`** — deterministic local storage; no Blob SAS or Managed Identity.

These match local development defaults in `backend/.env.example`.

---

## 11. Alembic validation

CI applies migrations on an **empty** database before tests:

```bash
uv run alembic upgrade head
uv run alembic current   # expect head: a8c3b1d92e47
```

This validates the migration chain independently of pytest. Tests use `drop_all` + `create_all`
via SQLAlchemy metadata in `conftest.py` and do not rely on Alembic at runtime.

---

## 12. Ruff lint

Blocking gate:

```bash
uv run ruff check .
```

Run from `backend/` with project config in `pyproject.toml` (`line-length = 100`, `target-version = py311`).

---

## 13. Ruff format debt (not gated)

**Backend formatting is not yet a blocking CI gate** because the repository contains preexisting
Ruff formatting drift (~30 legacy files). `ruff format --check .` fails repo-wide today.

Strategy: **Option A** — lint only until a dedicated formatting baseline block addresses drift.
Do not run mass `ruff format` as part of Block 6.1.

---

## 14. Flutter job

**Runner:** `ubuntu-latest`  
**Timeout:** 20 minutes  
**Working directory:** `mobile/`

Steps (in order):

1. Checkout
2. Flutter 3.13.7 stable (`subosito/flutter-action@v2`, `cache: true`)
3. `flutter pub get`
4. `git diff --exit-code pubspec.lock` (lockfile integrity)
5. `dart format --output=none --set-exit-if-changed .`
6. `flutter analyze`
7. `flutter test`

No iOS/Android/macOS build in this block.

---

## 15. Flutter version

Pinned to match project baseline:

| Tool | Version |
|------|---------|
| Flutter | 3.13.7 |
| Channel | stable |
| Dart | 3.1.3 (from `pubspec.yaml` constraint) |

Do not auto-upgrade to latest Flutter in CI.

---

## 16. Cloud E2E exclusion

`mobile/test/integration/cloud_progress_photos_e2e_test.dart` is **skipped by default**:

```dart
const _runCloudE2e = bool.fromEnvironment('RUN_CLOUD_E2E', defaultValue: false);
// ...
skip: !_runCloudE2e,
```

Regular `flutter test` discovers the file but reports it as **skipped** (~319 passed, 1 skipped).
CI does **not** set `RUN_CLOUD_E2E`, cloud API URL, or demo credentials.

### Manual cloud E2E (outside CI)

```bash
cd mobile
flutter test test/integration/cloud_progress_photos_e2e_test.dart \
  --dart-define=RUN_CLOUD_E2E=true \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=<api-url>
```

---

## 17. Cache

### Backend (uv)

`astral-sh/setup-uv@v5` with `enable-cache: true`. Cache key varies by OS, Python version, and
`uv.lock`. No manual redundant cache.

### Flutter

`subosito/flutter-action@v2` with `cache: true`. Considers Flutter version, OS, and `pubspec.lock`.

Do not cache `.env`, databases, JWT values, or Azure credentials.

---

## 18. Timeouts

| Job | Timeout |
|-----|---------|
| Backend quality | 15 minutes |
| Flutter quality | 20 minutes |

Adjust if GitHub-hosted runs consistently finish faster or slower.

---

## 19. Required checks (branch protection)

Suggested required status checks for `main`:

1. **Backend quality**
2. **Flutter quality**

Configure manually:

```text
GitHub repository → Settings → Branches (or Rulesets)
  → protect main
  → require pull request before merging
  → require status checks: Backend quality, Flutter quality
  → optional: require branch up to date, disallow force push
```

Block 6.1 does not configure branch protection via API or Terraform.

---

## 20. Local parity

Run the same commands locally before pushing.

### Backend

Requires PostgreSQL reachable at the CI URL (or equivalent local test DB):

```bash
# Optional: ephemeral Postgres matching CI
docker run -d --name fittrack-ci-pg \
  -e POSTGRES_USER=fittrack \
  -e POSTGRES_PASSWORD=fittrack \
  -e POSTGRES_DB=fittrack_test \
  -p 5432:5432 postgres:16

export DATABASE_URL='postgresql+psycopg://fittrack:fittrack@localhost:5432/fittrack_test'
export JWT_SECRET_KEY='ci-only-not-a-real-secret'
export AI_PROVIDER='fake'
export PROGRESS_PHOTO_STORAGE_PROVIDER='fake'

cd backend
uv sync --frozen
uv run alembic upgrade head
uv run alembic current
uv run ruff check .
uv run pytest

docker rm -f fittrack-ci-pg   # when done
```

### Flutter

```bash
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

---

## 21. Troubleshooting

### Backend: connection refused

- Confirm PostgreSQL service health and `pg_isready`.
- Verify `DATABASE_URL` uses `localhost:5432` and `postgresql+psycopg://`.
- Ensure port 5432 is not occupied locally when simulating CI.

### Alembic fails

- Check revision chain under `backend/alembic/versions/`.
- Confirm empty DB and required env vars (`DATABASE_URL`, `JWT_SECRET_KEY`).
- Async driver must match project (`psycopg`, not `asyncpg` unless project changes).

### Fake provider not selected

Symptoms: Azure credential errors or network attempts in tests.

Fix: set `AI_PROVIDER=fake` and `PROGRESS_PHOTO_STORAGE_PROVIDER=fake` in CI env.

### Flutter SDK mismatch

Symptoms: package resolution or Dart syntax errors.

Fix: use Flutter **3.13.7** stable locally (`flutter --version`).

### Cloud E2E attempts network in CI

Fix: confirm `RUN_CLOUD_E2E` is not set; test should appear as skipped, not failed.

### Cache corruption

- Re-run workflow with cache miss (change cache key temporarily) or disable cache in a debug branch.
- Do not delete or regenerate lockfiles to “fix” cache.

### Lockfile changed after `flutter pub get`

CI fails at `git diff --exit-code pubspec.lock`. Commit intentional lockfile updates or fix
dependency constraints locally.

---

## 22. Limitations (Block 6.1)

- Backend **Ruff format** is not a blocking gate (legacy drift).
- No code coverage thresholds.
- No Docker image build or ACR push.
- No Terraform fmt/validate/plan in Block 6.1 (implemented in Block 6.2 — see [terraform-ci-security.md](terraform-ci-security.md))
- No deployment or Azure integration tests in CI.
- No Android/iOS/macOS build (Block 6.4 candidate).
- No Python/Flutter version matrix.
- GitHub-hosted execution requires commit/push — local YAML validation alone is not final acceptance.
- Branch protection is manual.
- No Dependabot, CodeQL, or secret scanning workflows yet.

This block is **quality gates only**, not release automation.

---

## 23. Next block

**Block 6.3 — Azure OIDC + Protected Backend Deployment**

Planned scope:

- Azure OIDC federated identity for GitHub Actions
- Remote Terraform state backend
- Enable cloud-backed `terraform plan` with real inputs (never example-only OpenAI tfvars)
- Protected `terraform apply`, ACR push, migrations, smoke tests
- No long-lived Azure client secrets

Terraform static CI (Block 6.2) is documented in [docs/terraform-ci-security.md](terraform-ci-security.md).

---

## Block 6.2 — Terraform CI (complete)

Static Terraform validation and security checks are implemented in
[`.github/workflows/terraform-ci.yml`](../.github/workflows/terraform-ci.yml).

| Check | Status |
|-------|--------|
| **Terraform quality** | Implemented — fmt, validate, Trivy, Gitleaks, hygiene |
| **Terraform plan safety** | Scaffolded — skipped until Block 6.3 |

See [docs/terraform-ci-security.md](terraform-ci-security.md) for full details.

---

## 24. Previous block reference (Block 6.1)

**Block 6.1 — Backend and Flutter Quality Gates** — see [docs/github-actions-quality-gates.md](github-actions-quality-gates.md).

Do not start Block 6.3 until Block 6.2 workflows are green on GitHub.

---

## Action pinning

Workflows pin major versions of maintained actions:

| Action | Version |
|--------|---------|
| `actions/checkout` | v4 |
| `actions/setup-python` | v5 |
| `astral-sh/setup-uv` | v5 |
| `subosito/flutter-action` | v2 |

Full SHA pinning can be added in a later hardening pass.

---

## Badges

After the first successful run on `main`:

```markdown
![Backend CI](https://github.com/fellgar246/project-fittrack-ai/actions/workflows/backend-ci.yml/badge.svg)
![Flutter CI](https://github.com/fellgar246/project-fittrack-ai/actions/workflows/flutter-ci.yml/badge.svg)
```

Badges show “no status” until workflows have run at least once on the default branch.
