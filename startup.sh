#!/bin/bash

# Startup script for Render deployment
echo "Starting AI Mental Health Backend..."

# Set environment variables if not already set
export PORT=${PORT:-10000}
export PYTHONPATH=/app

# Run the Flask application
python app.py 