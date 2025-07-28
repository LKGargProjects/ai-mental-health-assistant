#!/usr/bin/env python3

from app import app

print("Testing Flask app routes:")
print("=" * 50)

# Check if the chat route is registered
if '/api/chat' in app.view_functions:
    print("✅ /api/chat route is registered")
    print(f"Function: {app.view_functions['/api/chat']}")
else:
    print("❌ /api/chat route is NOT registered")

# Check other routes
for route in ['/', '/api/health', '/api/ping']:
    if route in app.view_functions:
        print(f"✅ {route} route is registered")
    else:
        print(f"❌ {route} route is NOT registered")

print("\nAll registered routes:")
for route in app.view_functions:
    print(f"  {route}") 