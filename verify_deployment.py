#!/usr/bin/env python3
"""
Verify Render deployment configuration
"""

import requests
import json
import sys

def check_health(url="https://gentlequest.onrender.com"):
    """Check health endpoint"""
    print(f"Checking {url}/api/health...")
    try:
        response = requests.get(f"{url}/api/health", timeout=10)
        data = response.json()
        
        print("\n✅ API is reachable")
        print(f"  Status: {data.get('status', 'unknown')}")
        print(f"  Environment: {data.get('environment', 'unknown')}")
        print(f"  Database: {data.get('database', 'unknown')[:50]}...")
        print(f"  Redis: {data.get('redis', 'unknown')}")
        
        return data
    except Exception as e:
        print(f"❌ Failed to reach API: {e}")
        return None

def check_enterprise_status(url="https://gentlequest.onrender.com"):
    """Check enterprise features"""
    print(f"\nChecking {url}/api/enterprise/status...")
    try:
        response = requests.get(f"{url}/api/enterprise/status", timeout=10)
        if response.status_code == 404:
            print("⚠️  Enterprise endpoints not available (deploy may be pending)")
            return None
        
        data = response.json()
        print("✅ Enterprise endpoints available")
        for system, enabled in data.get('systems', {}).items():
            status = "✅" if enabled else "❌"
            print(f"  {status} {system}")
        return data
    except Exception as e:
        print(f"❌ Enterprise features check failed: {e}")
        return None

def test_chat(url="https://gentlequest.onrender.com"):
    """Test chat functionality"""
    print(f"\nTesting chat endpoint...")
    try:
        response = requests.post(
            f"{url}/api/chat",
            json={"message": "Hello, test message"},
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'response' in data:
                print("✅ Chat is working")
                print(f"  Response length: {len(data['response'])} chars")
                return True
        else:
            print(f"❌ Chat returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Chat test failed: {e}")
        return False

def check_required_env_vars():
    """List required environment variables"""
    print("\n📝 Required Environment Variables for Full Operation:")
    print("\nCRITICAL (Must Have):")
    print("  DATABASE_URL - PostgreSQL connection string")
    print("  GEMINI_API_KEY - For AI responses")
    print("  REDIS_URL - For session management (usually auto-configured)")
    
    print("\nENTERPRISE FEATURES (Optional but Recommended):")
    print("  ENCRYPTION_MASTER_KEY - For data encryption (you added: e6870...)")
    print("  STRIPE_SECRET_KEY - For payment processing")
    print("  ADMIN_API_TOKEN - For admin endpoints")
    
    print("\nOPTIONAL:")
    print("  OPENAI_API_KEY - Backup AI provider")
    print("  PPLX_API_KEY - Backup AI provider")
    print("  SENTRY_DSN_BACKEND - Error tracking")

def main():
    print("🔍 GentleQuest Deployment Verification")
    print("=" * 50)
    
    # Check health
    health_data = check_health()
    
    if health_data:
        # Check specific issues
        if "unhealthy" in health_data.get('database', ''):
            print("\n⚠️  DATABASE ISSUE DETECTED!")
            print("The PostgreSQL connection is failing.")
            print("\nPossible causes:")
            print("1. DATABASE_URL not set correctly in Render")
            print("2. PostgreSQL addon not attached")
            print("3. Connection string format issue")
            print("\nFix: In Render Dashboard > Environment:")
            print("  DATABASE_URL=postgresql://user:password@host:port/dbname")
    
    # Check enterprise
    enterprise_data = check_enterprise_status()
    
    # Test chat
    chat_works = test_chat()
    
    # Show required vars
    check_required_env_vars()
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 SUMMARY:")
    
    issues = []
    if health_data and "unhealthy" in health_data.get('database', ''):
        issues.append("Database connection")
    if not enterprise_data or not any(enterprise_data.get('systems', {}).values() if enterprise_data else []):
        issues.append("Enterprise features not configured")
    
    if not issues:
        print("✅ Everything is working correctly!")
    else:
        print(f"⚠️  Issues found: {', '.join(issues)}")
        print("\n🔧 NEXT STEPS:")
        print("1. Go to Render Dashboard: https://dashboard.render.com/web/srv-d2r3i1fdiees73dqtov0")
        print("2. Click on 'Environment' tab")
        print("3. Add/Update these variables:")
        print("   - DATABASE_URL (your PostgreSQL connection)")
        print("   - ENCRYPTION_MASTER_KEY (already added)")
        print("4. Click 'Save Changes'")
        print("5. Service will auto-redeploy")

if __name__ == "__main__":
    main()
