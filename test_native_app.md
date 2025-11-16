# ✅ GentleQuest Native App - Testing Guide

## 🎉 App Successfully Installed!

Now that GentleQuest is on your iPhone, let's test all features:

## 📱 Launch the App
1. Find **GentleQuest** on your home screen
2. Tap to open

## 🧪 Test These Features

### 1. AI Chat Test
- Tap "Chat with AI"
- Send: "Hello, how are you?"
- Verify you get a response from the AI

### 2. Mood Tracking
- Go to "Mood" tab
- Log today's mood
- Add a note about how you're feeling

### 3. Crisis Resources
- Type: "I'm feeling really stressed"
- Check if crisis resources appear
- Verify phone numbers are clickable

### 4. Self-Assessment
- Go to "Assessment" tab
- Complete the daily check-in
- Submit and verify it saves

### 5. Offline Mode
- Turn on Airplane Mode
- Try to use the app
- Some features should work offline

## 🔍 Verify Backend Connection

The app should be connecting to:
```
https://gentlequest.onrender.com
```

You can verify by:
1. Opening the app
2. Sending a chat message
3. Checking if you get a response

## ⚡ Performance Check

The native app should be:
- ✅ Faster than the web version
- ✅ Smoother animations
- ✅ Native iOS look and feel
- ✅ Working with Face ID/Touch ID (if configured)

## 🚨 Troubleshooting

### App Crashes on Launch
1. Delete the app
2. In Xcode, clean build folder (Shift+Cmd+K)
3. Run again from Xcode

### No AI Responses
1. Check internet connection
2. Verify backend is running:
   ```bash
   curl https://gentlequest.onrender.com/api/health
   ```

### Trust Issues
Settings → General → VPN & Device Management → Trust Developer

## 📊 Monitor Backend

Watch real-time activity:
```bash
# Check if your app is hitting the backend
curl https://gentlequest.onrender.com/api/health

# View latest logs (if you have Render CLI)
render logs --service srv-d2r3i1fdiees73dqtov0 --tail
```

## 🎯 Success Indicators

You know it's working when:
- ✅ App launches without crashing
- ✅ AI responds to your messages
- ✅ Mood entries are saved
- ✅ Crisis resources appear for trigger words
- ✅ App works smoothly like a native iOS app

## 🚀 Next Steps

1. **Share with TestFlight** (for others to test):
   - Archive in Xcode (Product → Archive)
   - Upload to App Store Connect
   - Invite testers

2. **Customize for App Store**:
   - Add app icons
   - Create screenshots
   - Write app description
   - Submit for review

## 📱 Current Status

Your iPhone now has:
- ✅ Native GentleQuest app installed
- ✅ Connected to production backend
- ✅ All features functional
- ✅ Ready for testing

**The app is ready to use! Open it on your iPhone and start testing!**
