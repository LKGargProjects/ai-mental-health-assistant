# Production Deployment Guide - Geography-Specific Crisis Detection

## 🚀 Deployment Status

**✅ DEPLOYED:** Geography-specific crisis detection with India-specific helplines

**🌐 Production URL:** https://ai-mental-health-assistant-tddc.onrender.com

**📅 Deployment Date:** Current session

## 📋 Production Testing Checklist

### **Phase 1: Basic Functionality Testing**
- [ ] **App loads correctly** on production URL
- [ ] **Chat interface works** - can send and receive messages
- [ ] **Crisis detection works** - "i want to die" triggers crisis response
- [ ] **Geography detection works** - shows India-specific helplines
- [ ] **Crisis widget displays** for high-risk messages
- [ ] **Helpline buttons work** - launch phone/SMS correctly

### **Phase 2: Geography-Specific Testing**
- [ ] **India-specific helplines** display correctly:
  - [ ] iCall Helpline: 022-25521111
  - [ ] AASRA: 91-22-27546669
  - [ ] Crisis Text Line: HOME to 741741
- [ ] **Crisis message** shows India-specific content
- [ ] **Phone buttons** launch external dialer
- [ ] **SMS button** launches text messaging

### **Phase 3: Edge Case Testing**
- [ ] **Non-crisis messages** don't show crisis widget
- [ ] **Different countries** get appropriate resources
- [ ] **IP geolocation** works for real users
- [ ] **Fallback resources** work for unsupported countries
- [ ] **Error handling** works gracefully

### **Phase 4: MVP User Testing**
- [ ] **Share with MVP testers** in India
- [ ] **Test crisis detection** with real users
- [ ] **Verify helpline functionality** in real environment
- [ ] **Collect user feedback** on experience
- [ ] **Monitor for issues** and bugs

## 🧪 Testing Commands

### **Test Crisis Detection:**
```bash
curl -X POST https://ai-mental-health-assistant-tddc.onrender.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "i want to die", "country": "in"}' | jq '.crisis_msg, .crisis_numbers'
```

### **Test Non-Crisis Message:**
```bash
curl -X POST https://ai-mental-health-assistant-tddc.onrender.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "hello", "country": "in"}' | jq '.risk_level'
```

## 📊 Monitoring

### **Key Metrics to Monitor:**
- [ ] **App response time** - should be under 5 seconds
- [ ] **Crisis detection accuracy** - should trigger for crisis keywords
- [ ] **Geography detection** - should identify user's country correctly
- [ ] **Button functionality** - should launch phone/SMS apps
- [ ] **Error rates** - should be minimal

### **Expected Behavior:**
1. **User types "i want to die"** → Crisis detected
2. **India-specific helplines** displayed in crisis widget
3. **Phone buttons** launch external dialer with correct numbers
4. **SMS button** launches text messaging with "HOME to 741741"

## 🚨 Rollback Plan

If issues are found:
1. **Immediate:** Revert to previous commit
2. **Investigation:** Check logs and debug locally
3. **Fix:** Address issues and redeploy
4. **Test:** Verify fixes work in production

## 📝 Post-Deployment Tasks

- [ ] **Monitor production logs** for errors
- [ ] **Test with real users** in India
- [ ] **Collect feedback** on user experience
- [ ] **Document any issues** found
- [ ] **Plan improvements** based on feedback

## 🎯 Success Criteria

**✅ Deployment Successful When:**
- App loads without errors
- Crisis detection works correctly
- India-specific helplines display
- Phone/SMS buttons function
- MVP testers can use the feature
- No critical errors in logs

---

**Status:** ✅ Deployed and ready for testing
**Next Step:** Test with MVP users in India 