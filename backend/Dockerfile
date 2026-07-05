# syntax=docker/dockerfile:1

# =============================================================================
# FitTrack AI — Production API image (Bloque 4.1)
#
# Multi-stage build:
#   - builder: resolves and installs dependencies into /app/.venv using uv +
#     the committed uv.lock (fully reproducible, no dev group).
#   - runtime: a slim image that ships only the virtualenv and the app source,
#     runs as a non-root user, and starts uvicorn directly (no uv at runtime).
#
# The image contains NO secrets and NO .env file. All configuration is injected
# at runtime via environment variables (see docs/docker-production.md).
# Database migrations are NOT run automatically at startup — see the README.
# =============================================================================

# ---------- Builder ----------
FROM python:3.11-slim AS builder

# Pinned uv (matches the local toolchain) copied from the official image.
COPY --from=ghcr.io/astral-sh/uv:0.9.9 /uv /uvx /bin/

# Reproducible, container-friendly uv behaviour:
#   - compile .pyc ahead of time for faster cold starts
#   - copy files instead of hardlinking (works across the cache mount)
#   - never download a managed Python; use the base image interpreter
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# 1) Install third-party dependencies first, without the project code.
#    This layer is cached and only rebuilds when pyproject.toml / uv.lock change.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# 2) Copy the application source and install the project into the venv.
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# ---------- Runtime ----------
FROM python:3.11-slim AS runtime

# - unbuffered stdout/stderr so logs stream to Azure Monitor / docker logs
# - no .pyc written at runtime (already compiled in the builder)
# - put the venv first on PATH so `uvicorn`/`alembic` resolve without uv
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH"

# Non-root system user for least-privilege at runtime.
RUN groupadd --system app && useradd --system --no-create-home --gid app app

WORKDIR /app

# Ship the fully built app (virtualenv + source) owned by the non-root user.
COPY --from=builder --chown=app:app /app /app

USER app

EXPOSE 8000

# Container-level liveness probe. Uses stdlib (no curl in slim images).
# Azure Container Apps uses its OWN health probes against /health — this
# HEALTHCHECK mainly benefits local `docker run` / `docker compose`.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).status == 200 else 1)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
