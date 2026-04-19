# Build stage
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-prod.txt /requirements-prod.txt
RUN pip install --no-cache-dir --prefix=/install -r /requirements-prod.txt

# Production stage
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    libjpeg62-turbo \
    libwebp7 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home appuser

COPY --from=builder /install /usr/local

WORKDIR /app

COPY --chown=appuser:appuser . .

RUN mkdir -p /app/staticfiles /app/media

# Collect static files at build time
RUN SECRET_KEY=temp-build-key \
    USE_SQLITE=True \
    python manage.py collectstatic --noinput 2>/dev/null || true

RUN chown -R appuser:appuser /app/staticfiles /app/media

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/api/health/ || exit 1

# Overridable via GUNICORN_WORKERS / GUNICORN_THREADS / GUNICORN_TIMEOUT env vars
# (see docker-compose.prod.yml). Defaults are tuned for a shared 2-core host.
ENV GUNICORN_WORKERS=2 GUNICORN_THREADS=2 GUNICORN_TIMEOUT=30
CMD gunicorn fsbo_backend.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers ${GUNICORN_WORKERS} \
    --threads ${GUNICORN_THREADS} \
    --timeout ${GUNICORN_TIMEOUT} \
    --graceful-timeout ${GUNICORN_TIMEOUT} \
    --access-logfile -
