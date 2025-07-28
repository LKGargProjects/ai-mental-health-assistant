#!/usr/bin/env python3

from crisis_detection import detect_crisis_level

# Test the crisis detection function
test_messages = [
    "I am feeling sad today",
    "I want to kill myself",
    "I feel hopeless",
    "I am happy today"
]

print("Testing crisis detection function:")
print("=" * 50)

for message in test_messages:
    risk_score, resources = detect_crisis_level(message)
    print(f"Message: '{message}'")
    print(f"Risk score: {risk_score} (type: {type(risk_score)})")
    print(f"Resources: {resources}")
    print("-" * 30) 