# Debug Summary: 400 Bad Request Issue

## Problem Analysis

The Flutter web app is still sending requests to `http://localhost:5055/api/...` instead of using relative URLs through the nginx proxy.

## Key Findings

### 1. Code Analysis ✅
- **ApiConfig.baseUrl** correctly returns empty string `''` for local development
- **Uri.base.host** detection logic is correct
- **No hardcoded URLs** found in compiled JavaScript
- **Docker container** was rebuilt with latest code

### 2. Caching Issues Identified 🔍
- **Nginx caching** was aggressive (1 year cache for static assets)
- **Browser cache** may be serving old JavaScript files
- **Docker layer caching** may have prevented updates

### 3. Debug Logging Added 📝
- Added comprehensive debug logging to `main.dart`
- Added cache-busting headers to nginx
- Created browser environment test file

## Current Status

### ✅ Fixed
1. **Nginx caching disabled** - Added no-cache headers
2. **Docker container rebuilt** - Latest code is deployed
3. **Debug logging added** - Will show environment detection

### 🔄 In Progress
1. **Browser cache clearing** - Need to test with hard refresh
2. **Environment detection** - Need to verify Uri.base.host detection

## Debug Steps Completed

### 1. Code Verification
```bash
# Checked for hardcoded URLs in compiled JS
grep -o "localhost[^\"]*" build/web/main.dart.js
# Result: Only found "localhost" in environment detection logic ✅

# Verified ApiConfig logic
# Result: Correctly returns empty string for localhost ✅
```

### 2. Docker Verification
```bash
# Rebuilt container without cache
docker-compose build --no-cache flutter-web
# Result: Fresh build completed ✅

# Restarted container
docker-compose up -d flutter-web
# Result: Container running with latest code ✅
```

### 3. Nginx Configuration
```nginx
# Disabled aggressive caching
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
}
```

## Next Steps for Testing

### 1. Browser Testing
1. **Open** `http://localhost:8080`
2. **Hard refresh** (Ctrl+Shift+R or Cmd+Shift+R)
3. **Clear browser cache** completely
4. **Check console** for debug messages:
   ```
   🚀 === FLUTTER APP STARTING ===
   🌐 kIsWeb: true
   🌐 Uri.base.host: localhost
   🌐 ApiConfig.baseUrl: 
   🌐 ApiConfig.environment: local
   ```

### 2. Expected Console Output
If working correctly, you should see:
```
🌐 API Config: Using relative URL (empty string) for nginx proxy
🌐 API Config: Uri.base.host = localhost
🌐 API Config: Uri.base = http://localhost:8080/
```

### 3. API Request Verification
The requests should now be:
- **Before**: `http://localhost:5055/api/self_assessment`
- **After**: `/api/self_assessment` (relative URL)

## Potential Issues

### 1. Browser Cache
- **Solution**: Hard refresh or clear cache completely
- **Test**: Open DevTools → Network → Disable cache

### 2. Service Worker Cache
- **Solution**: Unregister service worker
- **Test**: Application → Service Workers → Unregister

### 3. Docker Layer Caching
- **Solution**: Already rebuilt with --no-cache
- **Verification**: Container timestamp shows recent build

## Test Commands

### Check Container Logs
```bash
docker-compose logs flutter-web
```

### Test API Proxy Directly
```bash
curl -X GET http://localhost:8080/api/health
```

### Check Nginx Access Logs
```bash
docker-compose exec flutter-web tail -f /var/log/nginx/access.log
```

## Expected Resolution

After clearing browser cache and hard refresh:
1. **Debug messages** should show correct environment detection
2. **API requests** should use relative URLs
3. **Nginx proxy** should route `/api/` requests to backend
4. **400 errors** should be resolved

## Fallback Debugging

If the issue persists:
1. **Check browser console** for the debug messages
2. **Verify nginx proxy** is working with curl
3. **Test with different browser** or incognito mode
4. **Check if service worker** is interfering

## Files Modified for Debugging

1. **`ai_buddy_web/lib/main.dart`** - Added debug logging
2. **`ai_buddy_web/nginx.conf`** - Disabled caching
3. **`test_browser_debug.html`** - Created browser test file

The issue is likely a **browser caching problem** that should be resolved with the cache-busting headers and hard refresh. 