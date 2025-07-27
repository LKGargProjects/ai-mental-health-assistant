#!/bin/bash
# iOS Build Script for AI Mental Health Buddy

echo "🍎 Building iOS App..."

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release iOS app
flutter build ios --release

echo "✅ iOS app built successfully!"
echo "📱 App location: build/ios/iphoneos/Runner.app"
echo ""
echo "🚀 Next steps:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Archive the app in Xcode"
echo "3. Upload to App Store Connect"
echo "4. Or distribute via TestFlight" 