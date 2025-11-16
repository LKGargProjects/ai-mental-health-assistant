#!/bin/bash

echo "🚀 GentleQuest Native iOS Deployment"
echo "===================================="
echo ""
echo "📱 Building for iPhone 15 Pro Max..."

cd ai_buddy_web

# Build the iOS app
echo "🔨 Building release app..."
flutter build ios --release --no-codesign

# Install via Flutter
echo ""
echo "📲 Installing on your iPhone..."
flutter install -d 00008130-0014551A1498001C

echo ""
echo "✅ Installation complete!"
echo ""
echo "If the app doesn't open automatically:"
echo "1. Find 'GentleQuest' on your home screen"
echo "2. Tap to open"
echo ""
echo "If you see 'Untrusted Developer':"
echo "1. Go to Settings → General → VPN & Device Management"
echo "2. Find your developer account"
echo "3. Tap 'Trust'"
