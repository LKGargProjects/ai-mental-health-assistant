import requests
import json

API_URL = "http://localhost:5055/api/chat"

TESTS = [
    # Country override tests
    {"desc": "India override (crisis)", "data": {"message": "I want to die", "country": "in"}, "expect_country": "in"},
    {"desc": "US override (crisis)", "data": {"message": "I want to die", "country": "us"}, "expect_country": "us"},
    {"desc": "UK override (crisis)", "data": {"message": "I want to die", "country": "uk"}, "expect_country": "uk"},
    {"desc": "Unsupported country (crisis)", "data": {"message": "I want to die", "country": "xx"}, "expect_country": "generic"},
    # IP-based detection (mock IPs)
    {"desc": "India IP (crisis)", "data": {"message": "I want to die"}, "headers": {"X-Forwarded-For": "49.37.249.1"}, "expect_country": "in"},
    {"desc": "US IP (crisis)", "data": {"message": "I want to die"}, "headers": {"X-Forwarded-For": "8.8.8.8"}, "expect_country": "us"},
    # Fallback
    {"desc": "Unknown IP (crisis)", "data": {"message": "I want to die"}, "headers": {"X-Forwarded-For": "10.0.0.1"}, "expect_country": "generic"},
    # Non-crisis message
    {"desc": "India override (non-crisis)", "data": {"message": "hello", "country": "in"}, "expect_country": "in"},
]

def check_response(resp, expect_country):
    if resp.status_code != 200:
        return False, f"HTTP {resp.status_code}"
    try:
        data = resp.json()
    except Exception as e:
        return False, f"Invalid JSON: {e}"
    for field in ["crisis_msg", "crisis_numbers", "risk_level"]:
        if field not in data:
            return False, f"Missing field: {field}"
    
    # Check crisis-specific content only for crisis messages
    if data["risk_level"] == "crisis":
        if expect_country == "in" and "iCall" not in data["crisis_msg"]:
            return False, "India crisis_msg missing iCall"
        if expect_country == "us" and "988" not in data["crisis_msg"]:
            return False, "US crisis_msg missing 988"
        if expect_country == "uk" and "Samaritans" not in data["crisis_msg"]:
            return False, "UK crisis_msg missing Samaritans"
        if expect_country == "generic" and "befrienders" not in data["crisis_msg"] and "international" not in data["crisis_msg"]:
            return False, "Generic fallback missing in crisis_msg"
    
    return True, ""

def run_tests():
    print("\n=== Geography-Specific Crisis Detection Automated Tests ===\n")
    for i, test in enumerate(TESTS, 1):
        desc = test["desc"]
        data = test["data"]
        headers = test.get("headers", {})
        expect_country = test["expect_country"]
        try:
            resp = requests.post(API_URL, json=data, headers=headers, timeout=10)
        except Exception as e:
            print(f"[{i}] {desc}: FAIL (Request error: {e})")
            continue
        ok, msg = check_response(resp, expect_country)
        if ok:
            print(f"[{i}] {desc}: PASS")
        else:
            print(f"[{i}] {desc}: FAIL ({msg})")
            try:
                print("  Response:", json.dumps(resp.json(), indent=2))
            except:
                print("  Raw response:", resp.text)
    print("\n=== Test Complete ===\n")

if __name__ == "__main__":
    run_tests()