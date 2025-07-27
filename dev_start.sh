#!/bin/bash
# Development startup script

echo "🚀 Starting AI Mental Health API in development mode..."

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "📦 Activating virtual environment..."
    source venv/bin/activate
fi

# Install dependencies if needed
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Start the Flask development server
echo "🌐 Starting Flask development server..."
python app.py 