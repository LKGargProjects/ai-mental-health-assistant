#!/bin/bash
set -e

echo "Installing Python dependencies..."
pip install -r requirements.txt

echo "Installing Flutter..."
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.8-stable.tar.xz
tar xf flutter_linux_3.32.8-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"

echo "Building Flutter web app..."
cd ai_buddy_web
flutter config --enable-web
flutter build web --release --web-renderer canvaskit

echo "Build completed successfully!" 