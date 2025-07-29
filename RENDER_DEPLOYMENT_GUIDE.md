# 🚀 Render Deployment Guide

## ✅ Application Status: PRODUCTION READY

The AI Mental Health Assistant is now ready for deployment to Render. All issues have been resolved and the application is fully functional.

## 📋 Pre-Deployment Checklist

### ✅ Completed
- [x] All 400 Bad Request issues resolved
- [x] Self assessment form working
- [x] Chat functionality working
- [x] All API endpoints responding
- [x] Docker environment tested locally
- [x] Code committed and pushed to GitHub
- [x] render.yaml configured correctly
- [x] Production URLs updated
- [x] Debug logging removed for production

## 🎯 Deployment Configuration

### Services to Deploy

1. **Backend API Service** (`ai-mental-health-backend`)
   - Type: Web Service
   - Environment: Python
   - Plan: Free
   - Port: 10000

2. **Frontend Web Service** (`ai-mental-health-frontend`)
   - Type: Static Site
   - Environment: Static
   - Plan: Free
   - Build: Flutter Web

3. **Database** (`ai-mental-health-db`)
   - Type: PostgreSQL
   - Plan: Free
   - Database: mental_health

## 🔧 Required Environment Variables

### Backend Service Variables
```bash
PYTHON_VERSION=3.9.6
DATABASE_URL=postgresql://... (auto-generated from database)
SECRET_KEY=... (auto-generated)
GEMINI_API_KEY=your_gemini_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
PPLX_API_KEY=your_perplexity_api_key_here
AI_PROVIDER=gemini
PORT=10000
ENVIRONMENT=production
REDIS_URL=redis://localhost:6379
```

### Frontend Service Variables
```bash
API_URL=https://ai-mental-health-backend.onrender.com
```

## 📝 Deployment Steps

### Step 1: Connect to GitHub
1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click "New +" → "Blueprint"
3. Connect your GitHub repository: `LKGargProjects/ai-mental-health-assistant`

### Step 2: Configure Services
1. **Backend Service**:
   - Name: `ai-mental-health-backend`
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `python app.py`
   - Environment: Python

2. **Frontend Service**:
   - Name: `ai-mental-health-frontend`
   - Build Command: `cd ai_buddy_web && flutter build web --release --web-renderer canvaskit`
   - Publish Directory: `ai_buddy_web/build/web`
   - Environment: Static

3. **Database**:
   - Name: `ai-mental-health-db`
   - Type: PostgreSQL
   - Database: mental_health

### Step 3: Set Environment Variables
1. **Backend Service**:
   - `GEMINI_API_KEY`: Your Gemini API key
   - `OPENAI_API_KEY`: Your OpenAI API key (optional)
   - `PPLX_API_KEY`: Your Perplexity API key (optional)
   - `AI_PROVIDER`: gemini
   - `ENVIRONMENT`: production

2. **Frontend Service**:
   - `API_URL`: https://ai-mental-health-backend.onrender.com

### Step 4: Deploy
1. Click "Create Blueprint Instance"
2. Render will automatically:
   - Create the database
   - Build and deploy the backend
   - Build and deploy the frontend
   - Link all services together

## 🔍 Post-Deployment Verification

### 1. Backend Health Check
```bash
curl https://ai-mental-health-backend.onrender.com/api/health
```
Expected Response:
```json
{
  "status": "healthy",
  "environment": "production",
  "database": "healthy",
  "redis": "healthy"
}
```

### 2. Frontend Access
- URL: `https://ai-mental-health-frontend.onrender.com`
- Should load the Flutter web application
- Chat interface should be visible
- Self assessment form should work

### 3. API Endpoints Test
```bash
# Health check
curl https://ai-mental-health-backend.onrender.com/api/health

# Session creation
curl https://ai-mental-health-backend.onrender.com/api/get_or_create_session

# Chat endpoint (POST)
curl -X POST https://ai-mental-health-backend.onrender.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello", "session_id": "test"}'
```

## 🐛 Troubleshooting

### Common Issues

1. **Build Failures**
   - Check Render logs for Python/Flutter build errors
   - Verify all dependencies are in requirements.txt
   - Ensure Flutter version compatibility

2. **Database Connection Issues**
   - Verify DATABASE_URL is correctly set
   - Check if database service is running
   - Ensure database tables are created

3. **API Connection Issues**
   - Verify API_URL is set correctly in frontend
   - Check CORS configuration
   - Ensure backend service is running

4. **Environment Variables**
   - Verify all required API keys are set
   - Check that ENVIRONMENT=production
   - Ensure AI_PROVIDER is set to gemini

### Debug Commands
```bash
# Check backend logs
curl https://ai-mental-health-backend.onrender.com/api/health

# Check frontend build
curl https://ai-mental-health-frontend.onrender.com

# Test API endpoints
curl -X POST https://ai-mental-health-backend.onrender.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "test", "session_id": "test"}'
```

## 📊 Expected Performance

- **Backend Response Time**: < 3 seconds for AI chat
- **Frontend Load Time**: < 5 seconds
- **Database Operations**: < 1 second
- **Memory Usage**: Optimized for free tier

## 🔐 Security Considerations

1. **API Keys**: Store securely in Render environment variables
2. **CORS**: Configured for production domains
3. **Database**: PostgreSQL with proper authentication
4. **HTTPS**: Automatically provided by Render

## 📈 Monitoring

### Render Dashboard
- Monitor service health
- Check build logs
- View performance metrics
- Monitor error rates

### Application Logs
- Backend logs available in Render dashboard
- Frontend errors visible in browser console
- Database logs accessible via Render

## 🎉 Success Criteria

The deployment is successful when:

1. ✅ Backend health check returns 200
2. ✅ Frontend loads without errors
3. ✅ Chat functionality works
4. ✅ Self assessment form submits successfully
5. ✅ Database operations work
6. ✅ All API endpoints respond correctly

## 📞 Support

If deployment issues occur:

1. Check Render build logs
2. Verify environment variables
3. Test endpoints individually
4. Check service dependencies
5. Review application logs

---

## 🚀 Ready to Deploy!

Your application is now ready for production deployment on Render. Follow the steps above to deploy successfully.

**Status: �� PRODUCTION READY** 