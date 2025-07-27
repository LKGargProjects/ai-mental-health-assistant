#!/bin/bash
# Android Build Script for AI Mental Health Buddy

echo "🤖 Building Android APK..."

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

echo "✅ Android APK built successfully!"
echo "📱 APK location: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "🚀 Next steps:"
echo "1. Test the APK: flutter install"
echo "2. Upload to Google Play Console"
echo "3. Or distribute via direct download" 