#!/bin/bash
# Startup script for Azure App Service

# Install dependencies
pip install -r requirements.txt

# Run database migrations (if using Flask-Migrate)
# flask db upgrade

# Start the application
gunicorn --bind=0.0.0.0 --timeout=600 app:app 