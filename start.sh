#!/bin/bash

set -euo pipefail

# Determine environment (default to docker/local)
ENVIRONMENT_NAME="${ENVIRONMENT:-docker}"

# Decide nginx listen port
# In docker/local, always keep nginx on 80 to avoid conflicts with Gunicorn (5055).
# Only honor PORT when running on Render/production-like environments.
PORT_TO_USE="80"
if [ -n "${PORT:-}" ] && { [ -n "${RENDER:-}" ] || [ -n "${RENDER_SERVICE_ID:-}" ] || [ "${ENVIRONMENT_NAME}" = "render" ] || [ "${ENVIRONMENT_NAME}" = "production" ]; }; then
  PORT_TO_USE="${PORT}"
fi

echo "ENVIRONMENT=${ENVIRONMENT_NAME} | PORT env: ${PORT:-<not set>} | nginx listen port: ${PORT_TO_USE}"

# If chosen port differs from default 80, update nginx listen port
if [ "${PORT_TO_USE}" != "80" ]; then
  echo "Configuring nginx to listen on port ${PORT_TO_USE}..."
  sed -i "s/listen 80;/listen ${PORT_TO_USE};/g" /etc/nginx/nginx.conf
fi

# Start nginx in the background
echo "Starting nginx..."
nginx

# Wait a moment for nginx to start
sleep 2

# Start Flask application with Gunicorn (backend listens on 5055; nginx proxies /api to it)
echo "Starting Flask application..."
# Wait for dependencies (Postgres, Redis) to be ready
DB_HOST="db"
DB_USER="${POSTGRES_USER:-ai_buddy}"
DB_NAME="${POSTGRES_DB:-ai_buddy}"
REDIS_HOST="redis"

echo "Waiting for PostgreSQL at ${DB_HOST} (db=${DB_NAME} user=${DB_USER})..."
for i in $(seq 1 60); do
  if pg_isready -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t 1 >/dev/null 2>&1; then
    echo "PostgreSQL is ready."
    break
  fi
  echo "PostgreSQL not ready yet (attempt $i/60)..."
  sleep 1
done

echo "Waiting for Redis at ${REDIS_HOST}..."
for i in $(seq 1 60); do
  if redis-cli -h "${REDIS_HOST}" ping 2>/dev/null | grep -q PONG; then
    echo "Redis is ready."
    break
  fi
  echo "Redis not ready yet (attempt $i/60)..."
  sleep 1
done

# Diagnostics
which python || true
python --version || true
python -m gunicorn --version || true

# Use module invocation to avoid issues with gunicorn entrypoint script paths
# Add verbose logging to capture errors on startup
GUNICORN_WORKERS="${GUNICORN_WORKERS:-4}"
GUNICORN_TIMEOUT="${GUNICORN_TIMEOUT:-120}"
GUNICORN_LOG_LEVEL="${GUNICORN_LOG_LEVEL:-debug}"
GUNICORN_ARGS=(
  -b 0.0.0.0:5055
  --workers "${GUNICORN_WORKERS}"
  --timeout "${GUNICORN_TIMEOUT}"
  --keep-alive 5
  --access-logfile -
  --error-logfile -
  --log-level "${GUNICORN_LOG_LEVEL}"
)
echo "Launching gunicorn with args: ${GUNICORN_ARGS[*]}"
exec python -m gunicorn "${GUNICORN_ARGS[@]}" app:app