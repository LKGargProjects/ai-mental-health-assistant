#!/bin/bash

# Legacy startup script (deprecated)
echo "[startup.sh] Deprecated: This script is no longer used."
echo "Production uses Dockerfile CMD -> /start.sh (Nginx + Gunicorn)."
echo "If you intended to run locally, use: bash start_local.sh or docker-compose up."
exit 0