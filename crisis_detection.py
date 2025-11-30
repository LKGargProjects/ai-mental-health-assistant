import re
from datetime import datetime


def detect_crisis_level(message):
    """
    Analyze message for crisis indicators and return risk level.
    Returns risk level string: 'low', 'medium', 'high', 'crisis'
    """
    message = message.lower()

    # Crisis keywords with risk levels
    crisis_keywords = [
        "suicide",
        "kill myself",
        "want to die",
        "end my life",
        "end it all",
        "take me from this earth",
        "take me from earth",
        "remove me from earth",
    ]
    high_risk_keywords = [
        "hopeless",
        "worthless",
        "can't go on",
        "give up",
        "self harm",
        "hurt myself",
    ]
    medium_risk_keywords = [
        "sad",
        "depressed",
        "anxious",
        "stressed",
        "overwhelmed",
        "lonely",
    ]
    low_risk_keywords = ["tired", "worried", "concerned", "frustrated"]

    # Check for crisis level
    if any(keyword in message for keyword in crisis_keywords):
        return "crisis"

    # Check for high risk
    if any(keyword in message for keyword in high_risk_keywords):
        return "high"

    # Check for medium risk
    if any(keyword in message for keyword in medium_risk_keywords):
        return "medium"

    # Check for low risk
    if any(keyword in message for keyword in low_risk_keywords):
        return "low"

    return "low"
