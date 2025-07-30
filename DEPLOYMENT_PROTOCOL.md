# AI Mental Health Assistant - Deployment & Testing Protocol

## **Single Codebase Principle**
- **ONE CODEBASE** for all environments: Local, Docker, Render
- **NO ENVIRONMENT-SPECIFIC CODE** - Use dynamic configuration
- **AUTOMATED DEPLOYMENT** - Push to GitHub triggers Render deployment

## **Standardized Testing Protocol**

### **Pre-Testing Checklist**
1. ✅ All Docker services healthy
2. ✅ Backend API responding (`/api/health`)
3. ✅ Flutter web app built and copied to static folder
4. ✅ Database connection working
5. ✅ Redis connection working

### **Testing Sequence**
1. **Backend API Test** (30 seconds)
   ```bash
   curl -s http://localhost:5055/api/health | jq .
   ```

2. **Frontend Load Test** (10 seconds)
   ```bash
   curl -s http://localhost:8080 | head -5
   ```

3. **Feature Test** (2 minutes)
   - Chat functionality
   - Mood tracking
   - Assessment submission
   - Resources dialog
   - Settings dialog

### **Quick Reload Protocol**
- **Backend changes**: `docker-compose restart backend`
- **Frontend changes**: `flutter build web && cp -r ai_buddy_web/build/web/* static/ && docker-compose restart flutter-web`
- **Full reload**: `docker-compose down && docker-compose up -d`

## **Deployment Workflow**

### **Local Development**
1. Make code changes
2. Test locally: `docker-compose up -d`
3. Verify all features work
4. Commit and push to GitHub

### **Render Production**
1. Push to GitHub triggers auto-deployment
2. Render uses `build.sh` to build Flutter app
3. Flutter files copied to `static/` folder
4. Flask serves the Flutter app

### **Environment Detection**
- **Local**: `http://localhost:8080` → Docker environment
- **Production**: `https://ai-mental-health-backend.onrender.com` → Production environment
- **API URLs**: Automatically configured based on environment

## **Troubleshooting Protocol**

### **If Assessment Button Not Working**
1. Check browser console for errors
2. Verify API endpoint: `curl -X POST http://localhost:5055/api/self_assessment`
3. Check ApiService configuration
4. Rebuild Flutter app if needed

### **If UI Shows Old Version**
1. Clear browser cache
2. Rebuild Flutter: `flutter build web`
3. Copy to static: `cp -r ai_buddy_web/build/web/* static/`
4. Restart services: `docker-compose restart`

### **If Backend Not Responding**
1. Check Docker logs: `docker-compose logs backend`
2. Verify database connection
3. Check Redis connection
4. Restart backend: `docker-compose restart backend`

## **Quality Assurance Checklist**

### **Before Every Push**
- [ ] All Docker services healthy
- [ ] Backend API responding
- [ ] Frontend loading correctly
- [ ] All buttons functional (Chat, Mood, Assessment, Resources, Settings)
- [ ] Assessment submission working
- [ ] Mood tracking working
- [ ] Chat functionality working

### **After Render Deployment**
- [ ] Production URL accessible
- [ ] Flutter app showing (not Flask fallback)
- [ ] All features working in production
- [ ] API calls successful

## **Performance Optimization**
- **Hot Reload**: Use `docker-compose restart` instead of full rebuild
- **Caching**: Browser cache management for UI updates
- **Build Optimization**: Flutter web build optimization flags
- **Database**: Connection pooling and query optimization

## **Emergency Procedures**
- **Rollback**: Git revert to last working commit
- **Full Reset**: `docker-compose down -v && docker-compose up -d`
- **Cache Clear**: Browser hard refresh (Ctrl+F5)
- **Log Analysis**: `docker-compose logs` for debugging 