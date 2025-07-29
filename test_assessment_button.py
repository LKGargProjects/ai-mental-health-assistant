#!/usr/bin/env python3
"""
Test script to verify assessment button visibility and functionality
"""

import requests
import time

def test_assessment_button():
    print("🔍 Testing Assessment Button Visibility")
    print("=" * 50)
    
    # Test Flutter app is running
    print("1. Checking Flutter app...")
    try:
        response = requests.get("http://localhost:8080", timeout=5)
        if response.status_code == 200:
            print("✅ Flutter app is running on port 8080")
        else:
            print(f"❌ Flutter app failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Flutter app connection failed: {e}")
        return False
    
    # Test backend is running
    print("\n2. Checking backend...")
    try:
        response = requests.get("http://localhost:5055/api/health", timeout=5)
        if response.status_code == 200:
            print("✅ Backend is running on port 5055")
        else:
            print(f"❌ Backend failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend connection failed: {e}")
        return False
    
    print("\n🎯 Assessment Button Test Instructions:")
    print("=" * 50)
    print("1. Open your browser and go to: http://localhost:8080")
    print("2. Look at the bottom of the screen for two buttons:")
    print("   - 📊 Mood Tracker button (left)")
    print("   - 📋 Assessment button (right)")
    print("3. Click the assessment button (📋 icon)")
    print("4. You should see the assessment form appear")
    print("5. Try filling out the assessment and submitting it")
    
    print("\n🔧 Troubleshooting:")
    print("- If you don't see the assessment button, try refreshing the page")
    print("- If the button doesn't work, check the browser console for errors")
    print("- Make sure both Flutter app (8080) and backend (5055) are running")
    
    print("\n📱 Access URLs:")
    print("- Flutter App: http://localhost:8080")
    print("- Backend API: http://localhost:5055")
    print("- Health Check: http://localhost:5055/api/health")
    
    return True

if __name__ == "__main__":
    success = test_assessment_button()
    if success:
        print("\n✅ Ready for manual testing!")
    else:
        print("\n❌ Some services are not running properly.") 