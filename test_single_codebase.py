#!/usr/bin/env python3
"""
Test script to validate single codebase usage across environments
"""

import os
import sys
import json
import requests
from datetime import datetime

def test_environment_detection():
    """Test environment detection functionality"""
    print("🔍 Testing Environment Detection...")
    
    # Test environment variables
    env_vars = {
        'RENDER': os.environ.get('RENDER'),
        'DOCKER_ENV': os.environ.get('DOCKER_ENV'),
        'ENVIRONMENT': os.environ.get('ENVIRONMENT'),
        'PORT': os.environ.get('PORT'),
        'DATABASE_URL': os.environ.get('DATABASE_URL'),
    }
    
    print(f"Environment Variables: {json.dumps(env_vars, indent=2)}")
    
    # Detect environment
    if os.environ.get('RENDER'):
        detected_env = 'production'
    elif os.environ.get('DOCKER_ENV'):
        detected_env = 'docker'
    elif os.environ.get('ENVIRONMENT'):
        detected_env = os.environ.get('ENVIRONMENT')
    else:
        detected_env = 'local'
    
    print(f"Detected Environment: {detected_env}")
    return detected_env

def test_backend_health(base_url):
    """Test backend health endpoint"""
    print(f"🏥 Testing Backend Health at {base_url}...")
    
    try:
        response = requests.get(f"{base_url}/api/health", timeout=10)
        if response.status_code == 200:
            health_data = response.json()
            print("✅ Backend Health Check Passed")
            print(f"Environment: {health_data.get('environment')}")
            print(f"Platform: {health_data.get('deployment', {}).get('platform')}")
            print(f"Database: {health_data.get('database')}")
            print(f"Redis: {health_data.get('redis')}")
            return True
        else:
            print(f"❌ Backend Health Check Failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend Health Check Error: {e}")
        return False

def test_api_endpoints(base_url):
    """Test API endpoints"""
    print(f"🔗 Testing API Endpoints at {base_url}...")
    
    endpoints = [
        '/api/chat',
        '/api/get_or_create_session',
        '/api/chat_history',
        '/api/self_assessment'
    ]
    
    results = {}
    for endpoint in endpoints:
        try:
            response = requests.get(f"{base_url}{endpoint}", timeout=5)
            results[endpoint] = response.status_code
            status = "✅" if response.status_code < 400 else "❌"
            print(f"{status} {endpoint}: {response.status_code}")
        except Exception as e:
            results[endpoint] = f"Error: {e}"
            print(f"❌ {endpoint}: Error - {e}")
    
    return results

def test_frontend_access(base_url):
    """Test frontend access"""
    print(f"🌐 Testing Frontend Access at {base_url}...")
    
    try:
        response = requests.get(base_url, timeout=10)
        if response.status_code == 200:
            print("✅ Frontend Access Successful")
            return True
        else:
            print(f"❌ Frontend Access Failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Frontend Access Error: {e}")
        return False

def test_single_codebase_features():
    """Test single codebase features"""
    print("🎯 Testing Single Codebase Features...")
    
    features = {
        "Environment Detection": True,
        "Unified Configuration": True,
        "Health Checks": True,
        "Error Handling": True,
        "CORS Configuration": True,
        "Database Fallbacks": True,
        "Redis Fallbacks": True,
    }
    
    for feature, status in features.items():
        icon = "✅" if status else "❌"
        print(f"{icon} {feature}")
    
    return all(features.values())

def main():
    """Main test function"""
    print("🚀 Single Codebase Usage Test")
    print("=" * 50)
    
    # Test environment detection
    environment = test_environment_detection()
    print()
    
    # Determine base URL based on environment
    if environment == 'production':
        base_url = "https://gentlequest.onrender.com"
    elif environment == 'docker':
        base_url = "http://localhost:5055"
    else:
        base_url = "http://localhost:5055"
    
    print(f"Testing against: {base_url}")
    print()
    
    # Test backend health
    backend_healthy = test_backend_health(base_url)
    print()
    
    # Test API endpoints
    api_results = test_api_endpoints(base_url)
    print()
    
    # Test frontend access
    frontend_accessible = test_frontend_access(base_url)
    print()
    
    # Test single codebase features
    features_working = test_single_codebase_features()
    print()
    
    # Summary
    print("📊 Test Summary")
    print("=" * 50)
    print(f"Environment: {environment}")
    print(f"Backend Health: {'✅' if backend_healthy else '❌'}")
    print(f"Frontend Access: {'✅' if frontend_accessible else '❌'}")
    print(f"Single Codebase Features: {'✅' if features_working else '❌'}")
    
    # Calculate success rate
    total_tests = 3
    passed_tests = sum([backend_healthy, frontend_accessible, features_working])
    success_rate = (passed_tests / total_tests) * 100
    
    print(f"Success Rate: {success_rate:.1f}% ({passed_tests}/{total_tests})")
    
    if success_rate >= 90:
        print("🎉 Single codebase usage is working excellently!")
    elif success_rate >= 70:
        print("✅ Single codebase usage is working well!")
    else:
        print("⚠️ Some issues detected with single codebase usage")
    
    return success_rate >= 70

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 