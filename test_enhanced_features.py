#!/usr/bin/env python3
"""
Test script for enhanced mental health platform features
"""

import requests
import json
import time

BASE_URL = "http://localhost:5054"

def test_assessment_endpoints():
    """Test assessment-related endpoints"""
    print("🧪 Testing Assessment Endpoints...")
    
    # Test getting assessment questions
    try:
        response = requests.get(f"{BASE_URL}/assessments/start")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Assessment questions loaded: {data['total_questions']} questions")
        else:
            print(f"❌ Failed to get assessment questions: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing assessment questions: {e}")
        return False
    
    # Test submitting assessment
    try:
        sample_responses = [
            {
                "questionId": 1,
                "question": "How often do you feel overwhelmed by daily tasks?",
                "type": "multiple_choice",
                "options": ["Never", "Rarely", "Sometimes", "Often", "Always"],
                "category": "stress",
                "answer": "Sometimes"
            },
            {
                "questionId": 2,
                "question": "How would you rate your overall mood today?",
                "type": "scale",
                "min": 1,
                "max": 10,
                "category": "mood",
                "answer": "7"
            }
        ]
        
        response = requests.post(
            f"{BASE_URL}/assessments/submit",
            json={"responses": sample_responses}
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Assessment submitted successfully")
            print(f"   Score: {data['score']:.1f}%")
            print(f"   Feedback received: {len(data['feedback'])} characters")
        else:
            print(f"❌ Failed to submit assessment: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing assessment submission: {e}")
        return False
    
    return True

def test_task_endpoints():
    """Test task-related endpoints"""
    print("\n🧪 Testing Task Endpoints...")
    
    # Test getting tasks
    try:
        response = requests.get(f"{BASE_URL}/tasks")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Tasks loaded: {len(data['tasks'])} tasks available")
        else:
            print(f"❌ Failed to get tasks: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing tasks: {e}")
        return False
    
    # Test completing a task
    try:
        response = requests.post(f"{BASE_URL}/tasks/1/complete")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Task completed successfully")
            print(f"   Points earned: {data['points_earned']}")
        else:
            print(f"❌ Failed to complete task: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing task completion: {e}")
        return False
    
    # Test getting reminders
    try:
        response = requests.get(f"{BASE_URL}/reminders")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Reminders loaded: {len(data['reminders'])} reminders")
        else:
            print(f"❌ Failed to get reminders: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing reminders: {e}")
        return False
    
    return True

def test_progress_endpoints():
    """Test progress sharing endpoints"""
    print("\n🧪 Testing Progress Sharing Endpoints...")
    
    # Test sharing progress
    try:
        response = requests.post(
            f"{BASE_URL}/progress/share",
            json={
                "shared_text": "Feeling great today! Completed my first assessment.",
                "privacy_setting": "public"
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Progress shared successfully")
            print(f"   Post ID: {data['post_id']}")
        else:
            print(f"❌ Failed to share progress: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing progress sharing: {e}")
        return False
    
    # Test getting community feed
    try:
        response = requests.get(f"{BASE_URL}/community/feed")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Community feed loaded: {len(data['feed'])} posts")
        else:
            print(f"❌ Failed to get community feed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing community feed: {e}")
        return False
    
    return True

def test_assessment_history():
    """Test assessment history endpoint"""
    print("\n🧪 Testing Assessment History...")
    
    try:
        response = requests.get(f"{BASE_URL}/assessments/history")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Assessment history loaded: {len(data['history'])} assessments")
        else:
            print(f"❌ Failed to get assessment history: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing assessment history: {e}")
        return False
    
    return True

def test_stats():
    """Test enhanced stats endpoint"""
    print("\n🧪 Testing Enhanced Stats...")
    
    try:
        response = requests.get(f"{BASE_URL}/stats")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Enhanced stats loaded:")
            print(f"   Total sessions: {data['total_sessions']}")
            print(f"   Total assessments: {data['total_assessments']}")
            print(f"   Total task completions: {data['total_task_completions']}")
            print(f"   Total progress posts: {data['total_progress_posts']}")
        else:
            print(f"❌ Failed to get stats: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error testing stats: {e}")
        return False
    
    return True

def main():
    """Run all tests"""
    print("🚀 Testing Enhanced Mental Health Platform Features")
    print("=" * 60)
    
    tests = [
        test_assessment_endpoints,
        test_task_endpoints,
        test_progress_endpoints,
        test_assessment_history,
        test_stats,
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                print(f"❌ Test failed: {test.__name__}")
        except Exception as e:
            print(f"❌ Test error: {test.__name__} - {e}")
    
    print("\n" + "=" * 60)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Enhanced features are working correctly.")
    else:
        print("⚠️  Some tests failed. Please check the implementation.")
    
    return passed == total

if __name__ == "__main__":
    main() 