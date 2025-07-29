#!/usr/bin/env python3
"""
Test script for the self-assessment feature
"""

import requests
import json
import time

BASE_URL = "http://localhost:5055"

def test_assessment_feature():
    print("🧪 Testing Self-Assessment Feature")
    print("=" * 50)
    
    # 1. Create a session
    print("1. Creating session...")
    response = requests.get(f"{BASE_URL}/api/get_or_create_session")
    if response.status_code == 200:
        session_data = response.json()
        session_id = session_data['session_id']
        print(f"✅ Session created: {session_id}")
    else:
        print("❌ Failed to create session")
        return
    
    # 2. Test different assessment types
    assessments = [
        {
            "name": "Anxious Assessment",
            "data": {
                "mood": "anxious",
                "energy": "low", 
                "sleep": "poor",
                "stress": "high",
                "notes": "Feeling overwhelmed with work deadlines"
            }
        },
        {
            "name": "Happy Assessment", 
            "data": {
                "mood": "happy",
                "energy": "high",
                "sleep": "good", 
                "stress": "low",
                "notes": "Had a great day with friends!"
            }
        },
        {
            "name": "Depressed Assessment",
            "data": {
                "mood": "depressed",
                "energy": "very_low",
                "sleep": "excessive", 
                "stress": "very_high",
                "notes": "Feeling very down and hopeless",
                "crisis_level": "high"
            }
        },
        {
            "name": "Mixed Assessment",
            "data": {
                "mood": "mixed",
                "energy": "medium",
                "sleep": "interrupted",
                "stress": "medium",
                "notes": "Some good moments, some difficult ones",
                "anxiety_level": "moderate"
            }
        }
    ]
    
    print("\n2. Testing different assessment types...")
    for i, assessment in enumerate(assessments, 1):
        print(f"\n   {i}. {assessment['name']}")
        response = requests.post(
            f"{BASE_URL}/self_assessment",
            headers={
                "Content-Type": "application/json",
                "X-Session-ID": session_id
            },
            json=assessment['data']
        )
        
        if response.status_code == 201:
            result = response.json()
            print(f"   ✅ Success! Assessment ID: {result['id']}")
            print(f"   📊 Data: {json.dumps(assessment['data'], indent=6)}")
        else:
            print(f"   ❌ Failed: {response.status_code} - {response.text}")
        
        time.sleep(0.5)  # Small delay between requests
    
    # 3. Test chat functionality
    print("\n3. Testing chat functionality...")
    chat_response = requests.post(
        f"{BASE_URL}/api/chat",
        headers={"Content-Type": "application/json"},
        json={"message": "I just completed a self-assessment and I'm feeling better now"}
    )
    
    if chat_response.status_code == 200:
        chat_data = chat_response.json()
        print(f"✅ Chat working! Risk level: {chat_data.get('risk_level', 'unknown')}")
        print(f"🤖 AI Response: {chat_data.get('response', '')[:100]}...")
    else:
        print(f"❌ Chat failed: {chat_response.status_code}")
    
    print("\n🎉 Assessment feature testing completed!")
    print(f"📝 Session ID: {session_id}")
    print(f"🌐 Backend URL: {BASE_URL}")

if __name__ == "__main__":
    test_assessment_feature() 