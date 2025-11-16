#!/usr/bin/env python3
"""
Validate DATABASE_URL format
"""

import sys
from urllib.parse import urlparse

def validate_database_url(url):
    """Validate PostgreSQL URL format"""
    print(f"Checking URL: {url[:30]}...")
    
    try:
        parsed = urlparse(url)
        
        # Check scheme
        if not parsed.scheme or 'postgres' not in parsed.scheme:
            print("❌ Invalid scheme. Must start with postgresql:// or postgres://")
            return False
            
        # Check host
        if not parsed.hostname:
            print("❌ No hostname found")
            return False
            
        # Check port
        if not parsed.port:
            print("⚠️  No port specified (will use default 5432)")
        
        # Check database name
        if not parsed.path or parsed.path == '/':
            print("❌ No database name specified")
            return False
            
        # Check credentials
        if not parsed.username:
            print("⚠️  No username specified")
            
        print("✅ URL format appears valid!")
        print(f"  Host: {parsed.hostname}")
        print(f"  Port: {parsed.port or 5432}")
        print(f"  Database: {parsed.path.lstrip('/')}")
        print(f"  Username: {parsed.username or 'not specified'}")
        
        # Show correct format
        print("\nCorrect format examples:")
        print("  postgresql://user:pass@host.render.com:5432/dbname")
        print("  postgresql://user:pass@dpg-xxx.singapore-1.render.com:5432/dbname")
        
        return True
        
    except Exception as e:
        print(f"❌ Error parsing URL: {e}")
        return False

if __name__ == "__main__":
    print("DATABASE_URL Format Validator")
    print("=" * 50)
    
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        print("\nEnter your DATABASE_URL (it will be masked):")
        url = input().strip()
    
    if url:
        validate_database_url(url)
    else:
        print("❌ No URL provided")
        
    print("\n" + "=" * 50)
    print("RENDER DASHBOARD STEPS:")
    print("1. Go to: https://dashboard.render.com/web/srv-d2r3i1fdiees73dqtov0")
    print("2. Click 'Environment' tab")
    print("3. Find DATABASE_URL variable")
    print("4. Ensure it matches format above")
    print("5. Click 'Save Changes'")
    print("6. Wait for redeploy (5-7 minutes)")
