#!/usr/bin/env python3
"""
Comprehensive test script to verify web app functionality after fixes
"""

import requests
import json
import time
import sys

def test_backend_health():
    """Test backend health endpoint"""
    print("🔍 Testing backend health...")
    try:
        response = requests.get("http://localhost:5055/api/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Backend healthy - Port: {data.get('port')}, Provider: {data.get('provider')}")
            return True
        else:
            print(f"❌ Backend health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend health check error: {e}")
        return False

def test_assessment_api():
    """Test assessment API endpoint"""
    print("🔍 Testing assessment API...")
    try:
        data = {
            "mood": "happy",
            "energy": "high", 
            "sleep": "good",
            "stress": "low",
            "notes": "Test assessment"
        }
        headers = {
            "Content-Type": "application/json",
            "X-Session-ID": "test-session-123"
        }
        response = requests.post(
            "http://localhost:5055/api/self_assessment",
            json=data,
            headers=headers,
            timeout=5
        )
        if response.status_code == 201:
            result = response.json()
            print(f"✅ Assessment API working - {result.get('message')}")
            return True
        else:
            print(f"❌ Assessment API failed: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Assessment API error: {e}")
        return False

def test_chat_api():
    """Test chat API endpoint"""
    print("🔍 Testing chat API...")
    try:
        data = {"message": "I am feeling sad today"}
        response = requests.post(
            "http://localhost:5055/api/chat",
            json=data,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Chat API working - Risk level: {result.get('risk_level')}")
            return True
        else:
            print(f"❌ Chat API failed: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Chat API error: {e}")
        return False

def test_frontend_access():
    """Test frontend accessibility"""
    print("🔍 Testing frontend access...")
    try:
        response = requests.get("http://localhost:8080", timeout=5)
        if response.status_code == 200:
            print("✅ Frontend accessible on port 8080")
            return True
        else:
            print(f"❌ Frontend access failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Frontend access error: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Starting comprehensive web app test...")
    print("=" * 50)
    
    tests = [
        test_backend_health,
        test_assessment_api,
        test_chat_api,
        test_frontend_access
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        try:
            if test():
                passed += 1
        except Exception as e:
            print(f"❌ Test {test.__name__} crashed: {e}")
        print()
    
    print("=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Web app is working correctly.")
        print("\n📱 You can now:")
        print("   • Open http://localhost:8080 in your browser")
        print("   • Test the assessment form (📊 icon)")
        print("   • Test the chat functionality")
        print("   • Test on Android emulator")
        return True
    else:
        print("❌ Some tests failed. Please check the issues above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 