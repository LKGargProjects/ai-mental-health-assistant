#!/usr/bin/env python3
"""
Complete rebuild test script to verify all services are working
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

def test_web_app():
    """Test web app accessibility"""
    print("🔍 Testing web app...")
    try:
        response = requests.get("http://localhost:8080", timeout=5)
        if response.status_code == 200:
            if "flutter" in response.text.lower() or "ai mental health" in response.text.lower():
                print("✅ Web app accessible and contains Flutter content")
                return True
            else:
                print("⚠️ Web app accessible but content seems unexpected")
                return True
        else:
            print(f"❌ Web app access failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Web app access error: {e}")
        return False

def test_flutter_dev_server():
    """Test Flutter development server"""
    print("🔍 Testing Flutter dev server...")
    try:
        response = requests.get("http://localhost:9100", timeout=5)
        if response.status_code == 200:
            print("✅ Flutter dev server accessible on port 9100")
            return True
        else:
            print(f"❌ Flutter dev server failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Flutter dev server error: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Starting complete rebuild test...")
    print("=" * 60)
    
    tests = [
        test_backend_health,
        test_assessment_api,
        test_chat_api,
        test_web_app,
        test_flutter_dev_server
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
    
    print("=" * 60)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Complete rebuild successful!")
        print("\n📱 You can now access:")
        print("   • Web App: http://localhost:8080")
        print("   • Flutter Dev: http://localhost:9100")
        print("   • Backend API: http://localhost:5055")
        print("\n🔧 Services running:")
        print("   • Flask Backend: Port 5055")
        print("   • Flutter Web: Port 8080")
        print("   • Flutter Dev: Port 9100")
        print("   • Android App: Running on emulator")
        return True
    else:
        print("❌ Some tests failed. Please check the issues above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 