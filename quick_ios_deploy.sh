#!/bin/bash

echo "📱 Quick Deploy to iPhone 15 Pro Max"
echo "===================================="
echo ""

# Navigate to Flutter app
cd ai_buddy_web

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    echo "Please run: brew install flutter"
    exit 1
fi

# Update the API endpoint to production
echo "🔧 Updating API endpoint to production..."
cat > lib/config/api_config.dart << 'EOF'
class ApiConfig {
  static const String baseUrl = 'https://gentlequest.onrender.com';
  static const String apiPath = '/api';
  
  static String get apiUrl => '$baseUrl$apiPath';
  
  // Endpoints
  static String get chatEndpoint => '$apiUrl/chat';
  static String get healthEndpoint => '$apiUrl/health';
  static String get sessionEndpoint => '$apiUrl/get_or_create_session';
  static String get moodEndpoint => '$apiUrl/mood_entry';
  static String get assessmentEndpoint => '$apiUrl/self_assessment';
  static String get chatHistoryEndpoint => '$apiUrl/chat_history';
  static String get moodHistoryEndpoint => '$apiUrl/mood_history';
  static String get analyticsEndpoint => '$apiUrl/analytics/log';
}
EOF

echo "✅ Configuration updated"
echo ""
echo "📲 DEPLOYMENT OPTIONS:"
echo ""
echo "════════════════════════════════════════"
echo "OPTION 1: WIRELESS INSTALL (Recommended)"
echo "════════════════════════════════════════"
echo "1. Make sure your iPhone and Mac are on the same WiFi"
echo "2. On iPhone: Settings → Developer → Enable 'Developer Mode'"
echo "3. Run this command:"
echo ""
echo "   flutter run --release"
echo ""
echo "4. When prompted, select your iPhone from the list"
echo ""
echo "════════════════════════════════════════"
echo "OPTION 2: USB INSTALL"
echo "════════════════════════════════════════"
echo "1. Connect iPhone via USB cable"
echo "2. Trust this computer on your iPhone"
echo "3. Run:"
echo ""
echo "   flutter run --release -d <device_id>"
echo ""
echo "To find device_id, run: flutter devices"
echo ""
echo "════════════════════════════════════════"
echo "OPTION 3: BUILD IPA FOR SHARING"
echo "════════════════════════════════════════"
echo "   flutter build ipa --release"
echo ""
echo "This creates an .ipa file you can install via:"
echo "- Apple Configurator 2"
echo "- TestFlight"
echo "- Third-party tools like AltStore"
echo ""
echo "👉 Press Enter to check connected devices..."
read

echo ""
echo "🔍 Checking for devices..."
flutter devices

echo ""
echo "Ready to deploy! Run: flutter run --release"
