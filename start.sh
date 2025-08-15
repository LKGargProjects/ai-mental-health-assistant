#!/bin/bash

set -euo pipefail

PORT_TO_USE="${PORT:-80}"
echo "Render PORT env: ${PORT:-<not set>} | Using nginx listen port: ${PORT_TO_USE}"

# If PORT is provided (Render), update nginx listen port from 80 to $PORT
if [ -n "${PORT:-}" ]; then
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
exec gunicorn -b 0.0.0.0:5055 --workers 4 --timeout 120 --keep-alive 5 app:app