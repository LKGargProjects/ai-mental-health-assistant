#!/bin/bash

# iOS Deployment Script for GentleQuest
echo "🚀 GentleQuest iOS Deployment"
echo "=============================="

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install/macos"
    exit 1
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

echo "✓ Prerequisites checked"

cd ai_buddy_web

# Step 1: Update dependencies
echo "📦 Updating dependencies..."
flutter pub get

# Step 2: Update iOS deployment target
echo "📱 Configuring for iOS 15.0+..."
cd ios
sed -i '' "s/IPHONEOS_DEPLOYMENT_TARGET = .*/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g" Runner.xcodeproj/project.pbxproj
cd ..

# Step 3: Build for iOS
echo "🔨 Building iOS app..."
flutter build ios --release --no-codesign

echo ""
echo "✅ Build complete!"
echo ""
echo "📱 NEXT STEPS TO DEPLOY TO YOUR iPHONE:"
echo "========================================"
echo ""
echo "OPTION A: Direct to Device (Requires Apple Developer Account):"
echo "1. Open Xcode:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "2. In Xcode:"
echo "   - Select your iPhone 15 Pro Max as the target device"
echo "   - Sign in with your Apple ID (Xcode → Preferences → Accounts)"
echo "   - Select your team in Signing & Capabilities"
echo "   - Click the Play button to build and run"
echo ""
echo "OPTION B: TestFlight (Requires Apple Developer Account \$99/year):"
echo "1. Archive in Xcode:"
echo "   - Product → Archive"
echo "   - Upload to App Store Connect"
echo ""
echo "2. In App Store Connect:"
echo "   - Add to TestFlight"
echo "   - Share TestFlight link"
echo ""
echo "OPTION C: Local Testing (Free - 7 day limit):"
echo "1. Connect iPhone via USB"
echo "2. Trust computer on iPhone"
echo "3. Run: flutter run --release"
echo ""
echo "🎯 For immediate testing, use Option C!"
