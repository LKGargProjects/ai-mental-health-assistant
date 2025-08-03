# Comprehensive Crisis Detection Testing Protocol

## 🧪 **Pre-Testing Setup**

### **Environment Verification**
```bash
# 1. Check all services are running
docker-compose ps

# 2. Verify backend health
curl -s http://localhost:5055/api/health | jq .

# 3. Verify web app loads
curl -s http://localhost:8080 | head -5

# 4. Clear browser cache (if testing UI)
# Open browser and hard refresh (Ctrl+F5 / Cmd+Shift+R)
```

## 🔍 **API Level Testing**

### **Test Case 1: Crisis Level Keywords**
```bash
# Test 1.1: Direct suicide references
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to kill myself"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to end my life"}' | jq .

# Test 1.2: Self-harm references
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to hurt myself"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to cut myself"}' | jq .

# Expected: risk_level: "crisis"
```

### **Test Case 2: High Risk Keywords**
```bash
# Test 2.1: Hopelessness
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel hopeless"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I have no hope"}' | jq .

# Test 2.2: Worthlessness
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel worthless"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am useless"}' | jq .

# Test 2.3: Giving up
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to give up"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I cant go on"}' | jq .

# Expected: risk_level: "high"
```

### **Test Case 3: Medium Risk Keywords**
```bash
# Test 3.1: Depression
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am depressed"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel sad"}' | jq .

# Test 3.2: Anxiety
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am anxious"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel stressed"}' | jq .

# Test 3.3: Overwhelm
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel overwhelmed"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am lonely"}' | jq .

# Expected: risk_level: "medium"
```

### **Test Case 4: Low Risk Keywords**
```bash
# Test 4.1: Tiredness
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am tired"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel exhausted"}' | jq .

# Test 4.2: Worry
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am worried"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am concerned"}' | jq .

# Test 4.3: Frustration
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am frustrated"}' | jq .

# Expected: risk_level: "low"
```

### **Test Case 5: Normal Conversations**
```bash
# Test 5.1: Positive messages
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am happy today"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I feel good"}' | jq .

# Test 5.2: Neutral messages
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "How are you?"}' | jq .

# Expected: risk_level: "low" or not present
```

### **Test Case 6: Edge Cases**
```bash
# Test 6.1: Mixed messages
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am happy but also sad"}' | jq .

# Test 6.2: Partial matches
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die of laughter"}' | jq .

# Test 6.3: Case sensitivity
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I WANT TO DIE"}' | jq .

# Test 6.4: Empty message
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": ""}' | jq .

# Test 6.5: Very long message
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "This is a very long message that contains many words and I want to die somewhere in the middle of it and then continue with more words"}' | jq .
```

## 🎨 **UI Level Testing**

### **Test Case 7: Crisis Resources Display**
```bash
# Open web app
open http://localhost:8080
```

**Manual Testing Steps:**
1. **Crisis Level Test**
   - Type: "I want to die"
   - Expected: Red crisis resources widget appears
   - Verify: "Call 988" button is present
   - Verify: "Crisis Text Line" button is present
   - Verify: "988 Lifeline Chat" button is present

2. **High Risk Test**
   - Type: "I feel hopeless"
   - Expected: Orange high-risk resources widget appears
   - Verify: Crisis buttons are present
   - Verify: "Find a Therapist" button is present

3. **Medium Risk Test**
   - Type: "I am sad"
   - Expected: Blue medium-risk resources widget appears
   - Verify: Crisis buttons are present
   - Verify: "Find a Therapist" button is present

4. **Low Risk Test**
   - Type: "I am tired"
   - Expected: Light blue low-risk resources widget appears
   - Verify: "Find a Therapist" button is present

5. **No Risk Test**
   - Type: "I am happy"
   - Expected: No crisis resources widget appears

### **Test Case 8: Button Functionality**
```bash
# Test each crisis button
# 1. Call 988 button
# 2. Crisis Text Line button
# 3. 988 Lifeline Chat button
# 4. Find a Therapist button
```

**Manual Testing Steps:**
1. **Phone Number Test**
   - Click "Call 988" button
   - Expected: Phone dialer opens with 988
   - Note: May not work in browser, test on mobile

2. **Text Line Test**
   - Click "Crisis Text Line" button
   - Expected: SMS app opens with 741741
   - Note: May not work in browser, test on mobile

3. **Web Links Test**
   - Click "988 Lifeline Chat" button
   - Expected: Opens https://988lifeline.org/chat/
   - Click "Find a Therapist" button
   - Expected: Opens https://www.psychologytoday.com/us/therapists

### **Test Case 9: Visual Design**
**Manual Testing Steps:**
1. **Color Scheme Verification**
   - Crisis level: Red background and text
   - High risk: Orange/red background and text
   - Medium risk: Blue background and text
   - Low risk: Light blue background and text

2. **Widget Layout**
   - Verify widget appears below chat message
   - Verify proper spacing and padding
   - Verify buttons are properly aligned
   - Verify text is readable

3. **Responsive Design**
   - Test on different screen sizes
   - Verify buttons work on mobile
   - Verify text doesn't overflow

## 🔄 **Session Management Testing**

### **Test Case 10: Session Persistence**
```bash
# Test 10.1: Multiple messages in same session
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' | jq .

curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I am better now"}' | jq .

# Verify session_id remains consistent
```

### **Test Case 11: Session History**
```bash
# Test 11.1: Get chat history
curl -X GET http://localhost:5055/api/chat_history | jq .

# Expected: All previous messages with risk levels
```

## 🚀 **Performance Testing**

### **Test Case 12: Response Time**
```bash
# Test 12.1: Measure response time for crisis detection
time curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' > /dev/null

# Test 12.2: Measure response time for normal message
time curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}' > /dev/null
```

### **Test Case 13: Load Testing**
```bash
# Test 13.1: Multiple concurrent requests
for i in {1..10}; do
  curl -X POST http://localhost:5055/api/chat \
    -H "Content-Type: application/json" \
    -d '{"message": "I want to die"}' &
done
wait

# Test 13.2: Rate limiting
for i in {1..50}; do
  curl -X POST http://localhost:5055/api/chat \
    -H "Content-Type: application/json" \
    -d '{"message": "Test message"}' &
done
wait
```

## 🔧 **Error Handling Testing**

### **Test Case 14: Invalid Requests**
```bash
# Test 14.1: Missing message field
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{}' | jq .

# Test 14.2: Empty message
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": ""}' | jq .

# Test 14.3: Invalid JSON
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "test"' | jq .

# Test 14.4: Wrong content type
curl -X POST http://localhost:5055/api/chat \
  -d '{"message": "test"}' | jq .
```

### **Test Case 15: Network Issues**
```bash
# Test 15.1: Simulate slow connection
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' \
  --max-time 30 | jq .

# Test 15.2: Test timeout handling
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' \
  --connect-timeout 1 | jq .
```

## 📊 **Data Validation Testing**

### **Test Case 16: Response Structure**
```bash
# Test 16.1: Verify required fields
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' | jq '.response, .risk_level, .session_id'

# Test 16.2: Verify field types
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' | jq 'type(.response), type(.risk_level), type(.session_id)'

# Expected: string, string, string
```

### **Test Case 17: Risk Level Values**
```bash
# Test 17.1: Verify valid risk levels
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' | jq '.risk_level'

# Expected values: "crisis", "high", "medium", "low"
```

## 🎯 **Integration Testing**

### **Test Case 18: End-to-End Flow**
```bash
# Test 18.1: Complete user journey
# 1. Open web app
open http://localhost:8080

# 2. Type crisis message
# 3. Verify crisis resources appear
# 4. Click crisis button
# 5. Verify external link opens
```

### **Test Case 19: Cross-Browser Testing**
```bash
# Test 19.1: Different browsers
# - Chrome
# - Firefox
# - Safari
# - Edge

# Test 19.2: Mobile browsers
# - iOS Safari
# - Android Chrome
```

## 📋 **Test Results Template**

### **API Test Results**
| Test Case | Input | Expected Risk Level | Actual Risk Level | Status |
|-----------|-------|-------------------|------------------|---------|
| Crisis 1 | "I want to die" | crisis | | |
| Crisis 2 | "I want to kill myself" | crisis | | |
| High 1 | "I feel hopeless" | high | | |
| High 2 | "I feel worthless" | high | | |
| Medium 1 | "I am sad" | medium | | |
| Medium 2 | "I am anxious" | medium | | |
| Low 1 | "I am tired" | low | | |
| Low 2 | "I am worried" | low | | |
| Normal 1 | "I am happy" | low | | |
| Normal 2 | "Hello" | low | | |

### **UI Test Results**
| Test Case | Expected Behavior | Actual Behavior | Status |
|-----------|------------------|-----------------|---------|
| Crisis Widget | Red widget appears | | |
| High Widget | Orange widget appears | | |
| Medium Widget | Blue widget appears | | |
| Low Widget | Light blue widget appears | | |
| No Widget | No widget appears | | |
| 988 Button | Phone dialer opens | | |
| Text Button | SMS app opens | | |
| Chat Button | Web link opens | | |
| Therapist Button | Web link opens | | |

## 🚨 **Critical Test Cases (Must Pass)**

### **Critical API Tests**
```bash
# These MUST pass before deployment
echo "=== CRITICAL API TESTS ==="

echo "Test 1: Crisis detection"
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "I want to die"}' | jq '.risk_level'

echo "Test 2: Response structure"
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "test"}' | jq 'has("response"), has("risk_level"), has("session_id")'

echo "Test 3: Error handling"
curl -X POST http://localhost:5055/api/chat \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.error'
```

### **Critical UI Tests**
```bash
# These MUST pass before deployment
echo "=== CRITICAL UI TESTS ==="

echo "Test 1: Web app loads"
curl -s http://localhost:8080 | grep -q "AI Mental Health" && echo "PASS" || echo "FAIL"

echo "Test 2: Crisis resources display"
# Manual test: Type "I want to die" and verify crisis widget appears
```

## 🎯 **Deployment Checklist**

### **Pre-Deployment Tests**
- [ ] All critical API tests pass
- [ ] All critical UI tests pass
- [ ] Crisis detection working correctly
- [ ] Risk level parsing working correctly
- [ ] Crisis resources displaying correctly
- [ ] Error handling working correctly
- [ ] Performance acceptable (< 5 seconds response time)
- [ ] Cross-browser compatibility verified

### **Post-Deployment Tests**
- [ ] Production API responds correctly
- [ ] Production web app loads correctly
- [ ] Crisis detection works in production
- [ ] Crisis resources display in production
- [ ] External links work in production

---

**Status**: Ready for comprehensive testing
**Estimated Time**: 30-45 minutes
**Priority**: HIGH (before deployment) 