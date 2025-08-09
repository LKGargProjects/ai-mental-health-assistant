#!/bin/bash

# Start nginx in the background
echo "Starting nginx..."
nginx

# Wait a moment for nginx to start
sleep 2

# Start Flask application with Gunicorn
echo "Starting Flask application..."
exec gunicorn -b 0.0.0.0:5055 --workers 4 --timeout 120 --keep-alive 5 app:app 