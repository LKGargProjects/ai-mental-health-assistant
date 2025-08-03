# AI Mental Health Assistant - Deployment & Testing Protocol

## 🚀 Deployment Process

### Pre-Deployment Checklist
- [ ] All tests passing locally
- [ ] Environment variables configured
- [ ] Database migrations applied
- [ ] Static assets built and copied

### Testing Sequence
1. **Backend API Test**
2. **Frontend Build Test**
3. **Integration Test**
4. **Crisis Detection Test**
5. **Production Deployment**

### Crisis Detection Testing Protocol
1. **Backend Test**: `curl -X POST http://localhost:5055/api/chat -H "Content-Type: application/json" -d '{"message": "i want to die", "country": "in"}'`
2. **Frontend Test**: Send crisis message in chat interface
3. **UI Verification**: Check if crisis resources widget appears
4. **Geography Test**: Verify country-specific helplines display

### If Crisis Detection Not Working
1. **Check Backend Logs**: `docker-compose logs backend`
2. **Check Frontend Logs**: `docker-compose logs flutter-web`
3. **Verify API Response**: Test backend endpoint directly
4. **Check Browser Console**: Look for JavaScript errors
5. **Clear Browser Cache**: Use incognito mode or hard refresh

### Environment Difference Analysis
1. **Compare API Responses**: Test same endpoint on local vs production
2. **Check Environment Variables**: Verify all configs match
3. **Validate Frontend Build**: Ensure latest code is deployed
4. **Test Browser Compatibility**: Check different browsers/devices

## 🔧 **FLUTTER WEB DEPLOYMENT & DEBUGGING LEARNINGS**

### **Critical Flutter Web Issues Discovered:**

#### **1. Docker Container Rebuild Required**
- **Issue**: Flutter web app not loading updated code despite file changes
- **Root Cause**: Docker container serving cached `main.dart.js` 
- **Solution**: `docker-compose build flutter-web` forces complete rebuild
- **Lesson**: Always rebuild Flutter containers after code changes

#### **2. Browser Cache vs Docker Cache**
- **Issue**: Browser cache was blamed, but Docker layer cache was the real culprit
- **Root Cause**: Docker layers cache the Flutter build output
- **Solution**: Force rebuild with `--no-cache` or `docker-compose build flutter-web`
- **Lesson**: Distinguish between browser caching and Docker layer caching

#### **3. Debug Message Strategy**
- **Issue**: Console was empty, making debugging impossible
- **Solution**: Added extensive `print()` statements in Dart code
- **Key Debug Points**:
  - API request/response logging
  - Risk level parsing
  - Widget build calls
  - Crisis data parsing
- **Lesson**: Always add debug logging before troubleshooting

#### **4. API Response Parsing Issues**
- **Issue**: Backend returns correct data, frontend shows `null`
- **Root Cause**: Flutter `fromJson` not parsing new fields (`crisis_msg`, `crisis_numbers`)
- **Solution**: Update `Message` model and `api_service.dart`
- **Lesson**: API changes require corresponding frontend model updates

#### **5. Widget Rendering Debugging**
- **Issue**: Crisis widget not appearing despite correct data
- **Debug Strategy**: 
  - Force widget to always show for debugging
  - Add build method logging
  - Check conditional rendering logic
- **Lesson**: Use temporary "always show" flags for widget debugging

### **Deployment Best Practices:**

#### **For Flutter Web:**
1. **Always rebuild container** after code changes: `docker-compose build flutter-web`
2. **Add debug logging** before troubleshooting UI issues
3. **Test in incognito mode** to avoid browser cache issues
4. **Check browser console** for JavaScript errors and debug messages
5. **Verify API responses** directly before blaming frontend

#### **For Crisis Detection:**
1. **Test backend first** with curl to verify API responses
2. **Check risk level parsing** in frontend
3. **Verify crisis data fields** are being parsed correctly
4. **Test widget rendering** with forced display flags
5. **Validate geography-specific** responses work

#### **For Environment Differences:**
1. **Compare API responses** between environments
2. **Check Docker container versions** and rebuild dates
3. **Verify environment variables** are consistent
4. **Test with same data** across environments
5. **Use debug logging** to trace data flow

### **Debugging Checklist:**
- [ ] Backend API returns expected data
- [ ] Frontend parses API response correctly
- [ ] Risk level is set properly
- [ ] Crisis data fields are populated
- [ ] Widget build method is called
- [ ] Widget renders in UI
- [ ] No JavaScript errors in console
- [ ] No Docker layer caching issues

### **Common Pitfalls:**
1. **Forgetting to rebuild** Flutter containers
2. **Blaming browser cache** when it's Docker cache
3. **Not adding debug logging** before troubleshooting
4. **Not testing API directly** before debugging frontend
5. **Ignoring console errors** that indicate deeper issues
6. **❌ CRITICAL: Frontend calling wrong API endpoint**
   - **Issue**: Flutter app configured to call production API instead of local backend
   - **Root Cause**: `api_config.dart` had production URL for local development
   - **Symptoms**: Backend works correctly, but frontend receives different responses
   - **Solution**: Always verify API endpoint configuration in frontend
   - **Lesson**: Check `baseUrl` configuration before debugging API issues

### **API Endpoint Verification Protocol:**
1. **Check Frontend Config**: Verify `api_config.dart` points to correct backend
2. **Test Backend Directly**: Use curl to verify backend responses
3. **Check Network Tab**: Verify frontend is calling expected endpoint
4. **Compare Responses**: Ensure frontend and backend responses match
5. **Environment Consistency**: Use local backend for local development

## 📋 Quality Assurance Checklist

### Backend
- [ ] API endpoints responding correctly
- [ ] Crisis detection working
- [ ] Geography-specific responses
- [ ] Error handling implemented
- [ ] Logging configured

### Frontend
- [ ] Flutter app building successfully
- [ ] API integration working
- [ ] UI components rendering
- [ ] Crisis widget displaying
- [ ] Debug logging active

### Integration
- [ ] End-to-end crisis flow working
- [ ] Geography detection functional
- [ ] UI updates reflecting API changes
- [ ] No console errors
- [ ] Performance acceptable

## 🚨 Troubleshooting Protocol

### If Crisis Detection Not Working
1. **Check Backend Logs**: `docker-compose logs backend`
2. **Test API Directly**: Use curl to verify responses
3. **Check Frontend Logs**: `docker-compose logs flutter-web`
4. **Rebuild Flutter Container**: `docker-compose build flutter-web`
5. **Check Browser Console**: Look for JavaScript errors
6. **Test in Incognito**: Avoid browser cache issues

### If UI Not Updating
1. **Rebuild Flutter Container**: `docker-compose build flutter-web`
2. **Clear Browser Cache**: Use incognito mode
3. **Check Debug Logs**: Look for widget build messages
4. **Verify API Responses**: Test backend directly
5. **Check Model Parsing**: Ensure `fromJson` handles all fields

### If Environment Differences
1. **Compare API Responses**: Test same endpoint on both environments
2. **Check Container Versions**: Verify rebuild dates
3. **Validate Environment Variables**: Ensure consistency
4. **Test with Debug Logging**: Trace data flow
5. **Rebuild All Containers**: Force fresh deployment 

## 🚨 **PRODUCTION DEBUGGING GUIDE**

### **Common Production Issues & Solutions**

#### **Issue 1: "Static Folder Exists: False" / "Index.html Exists: False"**
**Symptoms:**
- Production shows Render default page instead of Flutter app
- Environment info shows static files missing
- "The Flutter web app is not available" message

**Root Cause:**
- Static files not being built or copied during deployment
- Wrong start command in render.yaml
- Nginx not serving static files correctly

**Solutions:**
1. **Check static files locally:**
   ```bash
   ls -la static/
   ls -la static/index.html static/main.dart.js
   ```

2. **Rebuild static files:**
   ```bash
   cd ai_buddy_web && flutter build web --release
   cd .. && yes | rm -rf static/* && cp -r ai_buddy_web/build/web/* static/
   ```

3. **Verify render.yaml configuration:**
   ```yaml
   buildCommand: ./build.sh
   startCommand: ./start.sh  # NOT python app.py
   ```

4. **Check Docker setup:**
   - Local: Use `docker-compose up -d` (separate containers)
   - Production: Use single container with nginx + Flask

#### **Issue 2: Mixed Geography Crisis Resources**
**Symptoms:**
- AI responses include generic crisis resources (988, 111, 741741)
- Crisis widget shows correct geography-specific resources
- Inconsistent crisis resource display

**Root Cause:**
- AI provider not aware of crisis detection results
- AI model trained to include crisis resources in responses

**Solutions:**
1. **Pass risk_level to AI provider:**
   ```python
   ai_response = get_gemini_response(message, session_id=session_id, risk_level=risk_level)
   ```

2. **Replace crisis AI responses:**
   ```python
   if risk_level == 'crisis':
       cleaned_response = """Generic supportive message without crisis resources"""
   ```

3. **Update crisis detection keywords:**
   ```python
   crisis_keywords = ['take me from this earth', 'remove me from earth']
   ```

#### **Issue 3: Environment Detection Issues**
**Symptoms:**
- Frontend calls wrong API endpoint
- Local development uses production API
- Production uses local API

**Root Cause:**
- Manual API config changes between environments
- No automatic environment detection

**Solutions:**
1. **Implement dynamic environment detection:**
   ```dart
   if (hostname == 'localhost' || hostname == '127.0.0.1') {
     return localUrl;
   } else {
     return productionUrl;
   }
   ```

2. **Use automatic environment detection:**
   - No manual code changes needed
   - Same codebase works in both environments

#### **Issue 4: Docker Container Issues**
**Symptoms:**
- Port conflicts: "port is already allocated"
- Backend inaccessible from host
- Container rebuilds not reflecting changes

**Solutions:**
1. **Clean up containers:**
   ```bash
   docker-compose down --remove-orphans
   docker-compose up -d
   ```

2. **Force rebuild:**
   ```bash
   docker-compose build --no-cache backend
   docker-compose up -d backend
   ```

3. **Check container logs:**
   ```bash
   docker-compose logs backend
   docker-compose logs flutter-web
   ```

#### **Issue 5: API Response Parsing Issues**
**Symptoms:**
- Crisis widget not displaying
- Risk level not being detected
- Missing crisis data fields

**Root Cause:**
- Frontend not parsing new API response fields
- Backend not returning expected data structure

**Solutions:**
1. **Update frontend parsing:**
   ```dart
   crisisMsg = data['crisis_msg'] as String;
   crisisNumbers = data['crisis_numbers'] as List<dynamic>;
   ```

2. **Verify backend response:**
   ```bash
   curl -X POST http://localhost:5055/api/chat \
     -H "Content-Type: application/json" \
     -d '{"message": "i want to die", "country": "in"}' | jq
   ```

### **Debugging Checklist**

#### **Pre-Deployment:**
- [ ] Static files built and copied to static/
- [ ] render.yaml uses correct start command
- [ ] All environment variables set in Render
- [ ] Local testing works on port 8080
- [ ] API responses include crisis data fields

#### **Post-Deployment:**
- [ ] Production URL loads Flutter app (not Render default page)
- [ ] Crisis detection works with geography-specific resources
- [ ] No mixed geography crisis resources
- [ ] API endpoints respond correctly
- [ ] Environment detection works automatically

#### **Monitoring:**
- [ ] Check Render deployment logs
- [ ] Monitor API response times
- [ ] Verify crisis detection accuracy
- [ ] Test with real users in India

### **Emergency Rollback Plan**

If critical issues are found:
1. **Immediate:** Revert to previous commit
2. **Investigation:** Check logs and debug locally
3. **Fix:** Address issues and redeploy
4. **Test:** Verify fixes work in production

---

**Status:** ✅ Production deployment issues resolved
**Next Step:** Monitor production deployment and test with MVP users 