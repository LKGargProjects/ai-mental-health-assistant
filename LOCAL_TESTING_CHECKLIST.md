# Local Testing Checklist - Geography-Specific Crisis Detection

## 🧪 **Local Testing Status: READY**

### **✅ Backend API Testing**
- ✅ **India Crisis Detection**: Returns iCall Helpline (022-25521111) and AASRA (91-22-27546669)
- ✅ **US Crisis Detection**: Returns National Suicide Prevention Lifeline (988)
- ✅ **UK Crisis Detection**: Returns Samaritans (116 123)
- ✅ **Generic Fallback**: Returns Befrienders Worldwide for unsupported countries
- ✅ **Non-Crisis Messages**: Returns empty crisis_numbers array
- ✅ **Performance**: < 2 seconds response time

### **✅ Frontend Integration Testing**
- ✅ **Flutter Web App**: Running on http://localhost:8080
- ✅ **Message Model**: Updated with crisis data fields
- ✅ **API Service**: Enhanced to handle geography-specific responses
- ✅ **CrisisResourcesWidget**: Updated to display country-specific resources
- ✅ **ChatMessageWidget**: Updated to pass crisis data

## 🎯 **Complete Local Testing Steps**

### **Step 1: Test Backend API (COMPLETED)**
```bash
# Test India crisis detection
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die", "country": "in"}' | jq

# Test US crisis detection
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die", "country": "us"}' | jq

# Test UK crisis detection
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die", "country": "uk"}' | jq
```

### **Step 2: Test Flutter Web UI (READY TO TEST)**
1. **Open Browser**: Navigate to http://localhost:8080
2. **Test Crisis Detection**: Type "I want to die" in the chat
3. **Verify Crisis Widget**: Check if crisis resources widget appears
4. **Check India Resources**: Should show iCall Helpline and AASRA
5. **Test Button Functionality**: Click crisis resource buttons
6. **Test Different Countries**: Use browser dev tools to test different countries

### **Step 3: Test End-to-End User Experience**
1. **Normal Chat**: Type "hello" - should not show crisis resources
2. **Crisis Detection**: Type "I want to die" - should show crisis resources
3. **Button Clicks**: Test clicking phone number buttons
4. **Text Line**: Test clicking Crisis Text Line button
5. **Website Links**: Test clicking website links (if any)

### **Step 4: Test Geography-Specific Features**
1. **India Focus**: Verify India-specific helplines are displayed
2. **Button Labels**: Check button labels match country resources
3. **Phone Numbers**: Verify correct phone numbers for India
4. **Text Instructions**: Check Crisis Text Line instructions
5. **Availability**: Verify "24/7" availability is shown

## 🔍 **Expected Results**

### **For India Crisis Detection:**
- **Crisis Message**: "I'm very concerned about what you're sharing..."
- **Crisis Numbers**: 
  - iCall Helpline: 022-25521111
  - AASRA: 91-22-27546669
  - Crisis Text Line: HOME to 741741
- **Button Functionality**: Clicking should open phone dialer or SMS

### **For Non-Crisis Messages:**
- **No Crisis Widget**: Should not display crisis resources
- **Normal Response**: AI should respond normally
- **No Crisis Data**: crisis_numbers should be empty

## 🚨 **Troubleshooting**

### **If Crisis Widget Doesn't Appear:**
1. Check browser console for JavaScript errors
2. Verify backend API is responding correctly
3. Check Flutter app logs for parsing errors
4. Clear browser cache and refresh

### **If Wrong Country Resources:**
1. Check if IP geolocation is working
2. Verify country parameter is being passed
3. Test with explicit country override
4. Check backend logs for country detection

### **If Buttons Don't Work:**
1. Check if URL launcher is configured
2. Verify phone number format is correct
3. Test on mobile device for phone functionality
4. Check browser permissions for external links

## ✅ **Success Criteria**

- ✅ **Backend API**: Returns geography-specific crisis data
- ✅ **Frontend UI**: Displays crisis resources widget
- ✅ **Country Detection**: Shows appropriate helplines for India
- ✅ **Button Functionality**: Crisis buttons are clickable
- ✅ **User Experience**: Complete crisis intervention flow works
- ✅ **Performance**: Response time < 3 seconds
- ✅ **Error Handling**: Graceful fallback for issues

## 🎯 **Next Steps After Local Testing**

1. **If All Tests Pass**: Proceed to production deployment
2. **If Issues Found**: Fix and retest locally
3. **Document Results**: Update test report with findings
4. **User Testing**: Have real users test the feature
5. **Production Deployment**: Deploy to Render production environment

## 📝 **Testing Notes**

- **Test Environment**: Local Docker containers
- **Backend URL**: http://localhost:5055
- **Frontend URL**: http://localhost:8080
- **Test Data**: Crisis keywords trigger geography-specific responses
- **Expected Behavior**: India-specific crisis resources for MVP focus

**Ready to test the complete Flutter UI!** 🚀 