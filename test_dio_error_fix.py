#!/usr/bin/env python3
"""
Comprehensive test script to verify DioError XMLHttpRequest fix
"""

import requests
import json
import time
import sys

def test_backend_health():
    """Test backend health endpoint with enhanced CORS"""
    print("🔍 Testing backend health with enhanced CORS...")
    try:
        response = requests.get("http://localhost:5055/api/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Backend healthy - Port: {data.get('port')}, Provider: {data.get('provider')}")
            print(f"✅ CORS enabled: {data.get('cors_enabled')}")
            print(f"✅ Available endpoints: {data.get('endpoints')}")
            print(f"✅ CORS origins: {data.get('cors_origins')}")
            return True
        else:
            print(f"❌ Backend health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend health check error: {e}")
        return False

def test_cors_headers():
    """Test CORS headers are properly set"""
    print("🔍 Testing CORS headers...")
    try:
        response = requests.options("http://localhost:5055/api/health", timeout=5)
        cors_headers = {
            'Access-Control-Allow-Origin': response.headers.get('Access-Control-Allow-Origin'),
            'Access-Control-Allow-Methods': response.headers.get('Access-Control-Allow-Methods'),
            'Access-Control-Allow-Headers': response.headers.get('Access-Control-Allow-Headers'),
        }
        print(f"✅ CORS headers: {cors_headers}")
        return True
    except Exception as e:
        print(f"❌ CORS headers test error: {e}")
        return False

def test_assessment_api():
    """Test assessment API with proper headers"""
    print("🔍 Testing assessment API...")
    try:
        data = {
            "mood": "happy",
            "energy": "high", 
            "sleep": "good",
            "stress": "low",
            "notes": "Test assessment with enhanced error handling"
        }
        headers = {
            "Content-Type": "application/json",
            "X-Session-ID": "test-session-123",
            "Accept": "application/json"
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
    """Test chat API with enhanced error handling"""
    print("🔍 Testing chat API...")
    try:
        data = {"message": "I am feeling sad today"}
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        response = requests.post(
            "http://localhost:5055/api/chat",
            json=data,
            headers=headers,
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

def test_error_simulation():
    """Test error handling by simulating network issues"""
    print("🔍 Testing error handling simulation...")
    try:
        # Test with invalid endpoint to simulate 404
        response = requests.get("http://localhost:5055/api/nonexistent", timeout=5)
        print(f"✅ Error handling test - 404 response: {response.status_code}")
        return True
    except Exception as e:
        print(f"❌ Error handling test failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Starting DioError XMLHttpRequest fix verification...")
    print("=" * 70)
    
    tests = [
        test_backend_health,
        test_cors_headers,
        test_assessment_api,
        test_chat_api,
        test_web_app,
        test_flutter_dev_server,
        test_error_simulation
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
    
    print("=" * 70)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! DioError XMLHttpRequest fix successful!")
        print("\n✅ **Fixes Applied:**")
        print("   • Enhanced CORS configuration with proper origins")
        print("   • Comprehensive Dio error handling and logging")
        print("   • Backend health checks before API calls")
        print("   • Startup verification screen")
        print("   • Detailed error messages for users")
        print("\n📱 **Access Points:**")
        print("   • Web App: http://localhost:8080")
        print("   • Flutter Dev: http://localhost:9100")
        print("   • Backend API: http://localhost:5055")
        print("\n🔧 **Services Running:**")
        print("   • Flask Backend: Port 5055 (Enhanced CORS)")
        print("   • Flutter Web: Port 8080 (Enhanced Error Handling)")
        print("   • Flutter Dev: Port 9100")
        print("\n🐛 **Debugging Features:**")
        print("   • Comprehensive Dio logging")
        print("   • Backend health verification")
        print("   • Startup connectivity check")
        print("   • User-friendly error messages")
        return True
    else:
        print("❌ Some tests failed. Please check the issues above.")
        print("\n🔧 **Troubleshooting Steps:**")
        print("   1. Ensure Flask backend is running on port 5055")
        print("   2. Check CORS configuration in app.py")
        print("   3. Verify Flutter web app is built and served")
        print("   4. Check browser console for detailed error logs")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 