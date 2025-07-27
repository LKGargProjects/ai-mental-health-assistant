#!/bin/bash
# Mobile Development Setup Script

echo "📱 Setting up mobile development environment..."

# Check if Android Studio is installed
if [ -d "/Applications/Android Studio.app" ]; then
    echo "✅ Android Studio is installed"
else
    echo "❌ Android Studio not found. Please install it from:"
    echo "   https://developer.android.com/studio"
    echo "   Or run: brew install --cask android-studio"
fi

# Check if Xcode is installed
if xcode-select -p &> /dev/null; then
    echo "✅ Xcode command line tools are installed"
else
    echo "❌ Xcode command line tools not found. Run:"
    echo "   xcode-select --install"
fi

# Check CocoaPods
if command -v pod &> /dev/null; then
    echo "✅ CocoaPods is installed"
else
    echo "❌ CocoaPods not found. Run:"
    echo "   sudo gem install cocoapods"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Open Android Studio and complete the setup wizard"
echo "2. Install Android SDK through Android Studio"
echo "3. Run: flutter doctor"
echo "4. Run: flutter config --android-sdk /path/to/android/sdk"
echo ""
echo "📱 To test mobile builds:"
echo "   cd ai_buddy_web"
echo "   flutter run -d android  # For Android"
echo "   flutter run -d ios      # For iOS" 