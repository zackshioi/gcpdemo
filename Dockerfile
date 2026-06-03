# Minimal image for Cloud Run. Cloud Run injects $PORT (defaults to 8080).
FROM python:3.13-slim

# Bring in the uv binary (matches local toolchain; pinned for reproducibility).
COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /bin/uv

WORKDIR /app

# Install deps first (cached across code changes). --frozen = use uv.lock as-is.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY app ./app

# Cloud Run sets PORT at runtime; bind to it. One worker is plenty for a demo.
ENV PORT=8080
CMD exec .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
