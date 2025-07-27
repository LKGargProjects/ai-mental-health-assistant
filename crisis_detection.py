import re
from datetime import datetime

def detect_crisis_level(message):
    """
    Analyze message for crisis indicators and return risk level and resources.
    Returns numeric risk score (0.0 to 1.0) and resources.
    """
    message = message.lower()
    
    # Crisis keywords
    high_risk_keywords = ['suicide', 'kill myself', 'want to die', 'end my life']
    medium_risk_keywords = ['hopeless', 'worthless', 'can\'t go on', 'give up']
    low_risk_keywords = ['sad', 'depressed', 'anxious', 'stressed']
    
    # Check for high risk
    if any(keyword in message for keyword in high_risk_keywords):
        return 1.0, [
            'National Suicide Prevention Lifeline: 988',
            'Crisis Text Line: Text HOME to 741741',
            'Emergency: Call 911'
        ]
    
    # Check for medium risk
    if any(keyword in message for keyword in medium_risk_keywords):
        return 0.7, [
            'Crisis Text Line: Text HOME to 741741',
            'Find a Therapist: https://www.psychologytoday.com/us/therapists',
            'SAMHSA National Helpline: 1-800-662-4357'
        ]
    
    # Check for low risk
    if any(keyword in message for keyword in low_risk_keywords):
        return 0.3, [
            'Find a Therapist: https://www.psychologytoday.com/us/therapists',
            'Mental Health Resources: https://www.nimh.nih.gov/health'
        ]
    
    return 0.0, None
