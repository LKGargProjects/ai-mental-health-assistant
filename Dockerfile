# =============================================================================
# SINGLE CONTAINER DOCKERFILE
# =============================================================================
# Multi-stage build for Flask backend + Flutter web in single container

##########
# Stage 1: Flutter web build (stable, preinstalled SDK)
##########
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

# Enable web support explicitly (no-op if already enabled)
RUN flutter config --enable-web

# Copy Flutter app and build web version (cache-friendly)
WORKDIR /app/ai_buddy_web
# Copy pubspec first to leverage Docker layer cache for pub get
COPY ai_buddy_web/pubspec.yaml ./pubspec.yaml
RUN flutter pub get
# Copy sources and assets only (minimal, deterministic)
COPY ai_buddy_web/lib ./lib
COPY ai_buddy_web/assets ./assets
COPY ai_buddy_web/web ./web
# Build Flutter web; disable PWA service worker to avoid stale cached UI on Render
# Add -v for verbose logs to surface exact compile errors from Dart/Flutter
RUN flutter build web --release --pwa-strategy=none -v

# Stage 2: Python backend build
FROM python:3.11-slim AS python-builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install -U python-dotenv gunicorn

# Copy Python application files
COPY app.py .
COPY models.py .
COPY crisis_detection.py .
COPY community.py .
COPY providers/ ./providers/
# Ensure data directory exists then copy the seed file
RUN mkdir -p /app/data
COPY data/community_seed.json ./data/community_seed.json

# Stage 3: Final production image
FROM python:3.11-slim

# Install nginx and PostgreSQL libraries
RUN apt-get update && apt-get install -y \
    nginx \
    libpq5 \
    postgresql-client \
    redis-tools \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Python dependencies and application
COPY --from=python-builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=python-builder /usr/local/bin /usr/local/bin
COPY --from=python-builder /app .

# Copy Flutter web build to both locations
COPY --from=flutter-builder /app/ai_buddy_web/build/web /var/www/html
COPY --from=flutter-builder /app/ai_buddy_web/build/web /app/static

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 5055

# Start both nginx and Flask app
CMD ["/start.sh"] 