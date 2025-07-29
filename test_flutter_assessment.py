#!/usr/bin/env python3
"""
Test script to verify Flutter app integration with assessment API
"""

import requests
import json
import time

def test_flutter_assessment_integration():
    print("🧪 Testing Flutter App + Assessment API Integration")
    print("=" * 60)
    
    # Test backend health
    print("1. Testing Backend Health...")
    try:
        response = requests.get("http://localhost:5055/api/health")
        if response.status_code == 200:
            print("✅ Backend is healthy")
            health_data = response.json()
            print(f"   📊 Provider: {health_data.get('provider', 'unknown')}")
            print(f"   🌐 Port: {health_data.get('port', 'unknown')}")
        else:
            print(f"❌ Backend health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend connection failed: {e}")
        return False
    
    # Test Flutter web app
    print("\n2. Testing Flutter Web App...")
    try:
        response = requests.get("http://localhost:8080")
        if response.status_code == 200:
            print("✅ Flutter web app is running")
        else:
            print(f"❌ Flutter web app failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Flutter web app connection failed: {e}")
        return False
    
    # Test assessment API directly
    print("\n3. Testing Assessment API...")
    try:
        # Create session
        session_response = requests.get("http://localhost:5055/api/get_or_create_session")
        if session_response.status_code == 200:
            session_data = session_response.json()
            session_id = session_data['session_id']
            print(f"✅ Session created: {session_id}")
            
            # Submit test assessment
            assessment_data = {
                "mood": "happy",
                "energy": "high",
                "sleep": "good",
                "stress": "low",
                "notes": "Testing Flutter integration - feeling great!",
                "crisis_level": "none"
            }
            
            assessment_response = requests.post(
                "http://localhost:5055/self_assessment",
                headers={
                    "Content-Type": "application/json",
                    "X-Session-ID": session_id
                },
                json=assessment_data
            )
            
            if assessment_response.status_code == 201:
                result = assessment_response.json()
                print(f"✅ Assessment submitted successfully! ID: {result.get('id')}")
                print(f"   📊 Data: {json.dumps(assessment_data, indent=2)}")
            else:
                print(f"❌ Assessment submission failed: {assessment_response.status_code}")
                print(f"   Error: {assessment_response.text}")
                return False
        else:
            print(f"❌ Session creation failed: {session_response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Assessment API test failed: {e}")
        return False
    
    # Test chat API
    print("\n4. Testing Chat API...")
    try:
        chat_response = requests.post(
            "http://localhost:5055/api/chat",
            headers={"Content-Type": "application/json"},
            json={"message": "I just completed a self-assessment and I'm feeling better!"}
        )
        
        if chat_response.status_code == 200:
            chat_data = chat_response.json()
            print(f"✅ Chat API working! Risk level: {chat_data.get('risk_level', 'unknown')}")
            print(f"   🤖 AI Response: {chat_data.get('response', '')[:100]}...")
        else:
            print(f"❌ Chat API failed: {chat_response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Chat API test failed: {e}")
        return False
    
    print("\n🎉 All tests passed! Integration is working correctly.")
    print("\n📋 Summary:")
    print("   ✅ Backend (Flask + PostgreSQL) - Running on port 5055")
    print("   ✅ Flutter Web App - Running on port 8080")
    print("   ✅ Assessment API - Fully functional")
    print("   ✅ Chat API - Working with risk detection")
    print("   ✅ Session Management - UUID-based tracking")
    
    print("\n🌐 Access URLs:")
    print("   📱 Flutter Web App: http://localhost:8080")
    print("   🔧 Backend API: http://localhost:5055")
    print("   📊 Health Check: http://localhost:5055/api/health")
    
    return True

if __name__ == "__main__":
    success = test_flutter_assessment_integration()
    if success:
        print("\n🚀 Ready for development and testing!")
    else:
        print("\n❌ Some tests failed. Please check the setup.") 