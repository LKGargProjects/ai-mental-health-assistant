#!/bin/bash
# startup.sh - Script to start the Flask application on Render

echo "Starting AI Mental Health API..."

# Install dependencies
pip install -r requirements.txt

# Start the application with gunicorn
exec gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 8 --timeout 0 app:app 