# 📱 Install GentleQuest on iPhone 15 Pro Max

## Quickest Method (30 seconds)

### Step 1: Open this link on your iPhone
```
https://gentlequest.onrender.com
```

### Step 2: Make it an App
1. Tap the **Share** button (box with arrow)
2. Scroll down, tap **"Add to Home Screen"**
3. Name: **GentleQuest**
4. Tap **Add**

## Features Available
✅ AI Mental Health Chat
✅ Mood Tracking
✅ Crisis Resources
✅ Self-Assessment
✅ Offline Support (PWA)

## Native App Installation (Advanced)

If you want the full native iOS app:

### Prerequisites
- Xcode installed
- Apple Developer account (free for testing)

### Steps
1. Open Terminal and run:
```bash
cd /Users/lokeshgarg/ai-mvp-backend/ai_buddy_web
open ios/Runner.xcworkspace
```

2. In Xcode:
   - Select "Runner" in the left panel
   - Go to "Signing & Capabilities"
   - Check "Automatically manage signing"
   - Select your team
   - Click the Play button

3. On iPhone:
   - Settings → General → VPN & Device Management
   - Trust the developer certificate

## Troubleshooting

### "Untrusted Developer" Error
- Go to Settings → General → VPN & Device Management
- Find your developer account
- Tap "Trust"

### Build Errors
```bash
cd /Users/lokeshgarg/ai-mvp-backend/ai_buddy_web
flutter clean
flutter pub get
flutter run --release
```

## Support
The app is fully functional at https://gentlequest.onrender.com
All features work perfectly in Safari with offline support!
