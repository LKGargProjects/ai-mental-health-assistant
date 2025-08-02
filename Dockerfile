# =============================================================================
# SINGLE CONTAINER DOCKERFILE
# =============================================================================
# Multi-stage build for Flask backend + Flutter web in single container

# Stage 1: Flutter web build
FROM debian:latest AS flutter-builder

# Install Flutter dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
ENV FLUTTER_HOME="/flutter"
ENV FLUTTER_VERSION="3.32.8"
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME
WORKDIR $FLUTTER_HOME
RUN git fetch && git checkout $FLUTTER_VERSION

# Add Flutter to PATH
ENV PATH="$FLUTTER_HOME/bin:$PATH"

# Enable web support
RUN flutter config --enable-web

# Copy Flutter app and build web version
WORKDIR /app
COPY ai_buddy_web/ ./ai_buddy_web/
WORKDIR /app/ai_buddy_web
RUN flutter build web --release

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
COPY providers/ ./providers/

# Stage 3: Final production image
FROM python:3.11-slim

# Install nginx and PostgreSQL libraries
RUN apt-get update && apt-get install -y \
    nginx \
    libpq5 \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Python dependencies and application
COPY --from=python-builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=python-builder /usr/local/bin /usr/local/bin
COPY --from=python-builder /app .

# Copy Flutter web build
COPY --from=flutter-builder /app/ai_buddy_web/build/web /var/www/html

# Copy static web files
COPY web/ /var/www/html/static/

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 5055

# Start both nginx and Flask app
CMD ["/start.sh"] 