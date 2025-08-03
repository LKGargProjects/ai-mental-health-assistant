# Crisis Resources Widget Debug

## 🎯 **Issue Analysis**

### **What We Expected**
When user types "I want to die", we should see:
1. ✅ AI crisis intervention message (WORKING)
2. ❌ Red crisis resources widget with buttons (NOT WORKING)

### **Expected Crisis Resources Widget**
```
┌─────────────────────────────────────┐
│ 🚨 Immediate Help Available         │
│ If you're in crisis, please reach  │
│ out. Help is available 24/7.       │
│                                     │
│ [📞 Call 988] [💬 988 Lifeline]   │
│ [📱 Crisis Text Line] [👤 Find a  │
│ Therapist]                          │
└─────────────────────────────────────┘
```

### **What We're Actually Getting**
- ✅ AI crisis intervention message with helpline numbers
- ❌ No crisis resources widget

## 🔍 **Root Cause Investigation**

### **Possible Issues**
1. **Flutter App Not Parsing Risk Level** - Risk level not being set correctly
2. **JavaScript Error** - Widget not rendering due to JS error
3. **CSS/Styling Issue** - Widget hidden or not styled correctly
4. **Widget Logic Issue** - Condition not met for displaying widget

### **Debug Steps**

#### **Step 1: Check Browser Console**
```bash
# Open browser developer tools
# Check for JavaScript errors when typing "I want to die"
```

#### **Step 2: Verify Risk Level Parsing**
```bash
# Test API response parsing
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' | jq '.risk_level'
```

#### **Step 3: Check Flutter App Logic**
The widget should display when:
- `message.riskLevel != RiskLevel.none` ✅
- `!message.isUser` ✅ (AI message)
- Risk level is properly parsed from API response ❓

#### **Step 4: Test Different Risk Levels**
```bash
# Test high risk
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel hopeless"}' | jq '.risk_level'

# Test medium risk  
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am sad"}' | jq '.risk_level'
```

## 🧪 **Manual Testing Protocol**

### **Test 1: Browser Console Check**
1. Open http://localhost:8080
2. Open browser developer tools (F12)
3. Go to Console tab
4. Type "I want to die"
5. Check for JavaScript errors

### **Test 2: Widget Visibility Check**
1. Type "I want to die"
2. Look for any red/orange widget below the AI response
3. Check if widget is hidden by CSS
4. Inspect element to see if widget HTML exists

### **Test 3: Different Keywords Test**
1. Type "I feel hopeless" (should show high risk widget)
2. Type "I am sad" (should show medium risk widget)
3. Type "I am tired" (should show low risk widget)

## 🔧 **Potential Fixes**

### **Fix 1: Rebuild Flutter App**
```bash
cd ai_buddy_web
flutter build web
cp -r build/web/* ../static/
docker-compose restart flutter-web
```

### **Fix 2: Check Risk Level Mapping**
Verify that "crisis" maps to `RiskLevel.high` in the Flutter app:
```dart
case 'crisis':
case 'high':
  riskLevel = RiskLevel.high;
  break;
```

### **Fix 3: Add Debug Logging**
Add console logging to see what risk level is being parsed:
```dart
print('Parsed risk level: $riskLevel');
```

## 📋 **Test Results**

### **Browser Console Check**
- [ ] No JavaScript errors
- [ ] Risk level parsing logs visible
- [ ] Widget HTML present in DOM

### **Widget Visibility Check**
- [ ] Crisis widget appears for crisis keywords
- [ ] High risk widget appears for high risk keywords
- [ ] Medium risk widget appears for medium risk keywords
- [ ] Low risk widget appears for low risk keywords

### **API Response Check**
- [ ] API returns correct risk_level
- [ ] Flutter app parses risk_level correctly
- [ ] Risk level maps to correct widget type

---

**Status**: 🔍 **INVESTIGATING**
**Priority**: HIGH
**Impact**: Crisis resources not accessible to users 