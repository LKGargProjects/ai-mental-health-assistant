from textblob import TextBlob
import re
from datetime import datetime

class CrisisDetector:
    def __init__(self):
        # Crisis keywords based on mental health research
        self.critical_keywords = [
            'suicide', 'kill myself', 'end it all', 'not worth living',
            'better off dead', 'want to die', 'hurt myself'
        ]
        
        self.high_risk_keywords = [
            'hopeless', 'worthless', 'hate myself', 'can\'t go on',
            'everyone hates me', 'no point', 'give up'
        ]
        
        self.medium_risk_keywords = [
            'stressed', 'overwhelmed', 'anxious', 'depressed',
            'scared', 'lonely', 'tired of everything'
        ]
    
    def analyze_message(self, message):
        """Analyze message for crisis indicators and return risk level"""
        message_lower = message.lower()
        
        # Check for critical risk indicators
        for keyword in self.critical_keywords:
            if keyword in message_lower:
                return {
                    'risk_level': 'critical',
                    'risk_score': 0.9,
                    'intervention': 'immediate',
                    'resources': self.get_crisis_resources()
                }
        
        # Check for high risk indicators
        high_risk_count = sum(1 for keyword in self.high_risk_keywords if keyword in message_lower)
        if high_risk_count >= 2:
            return {
                'risk_level': 'high',
                'risk_score': 0.7,
                'intervention': 'urgent',
                'resources': self.get_support_resources()
            }
        
        # Check for medium risk indicators
        medium_risk_count = sum(1 for keyword in self.medium_risk_keywords if keyword in message_lower)
        if medium_risk_count >= 2:
            return {
                'risk_level': 'medium',
                'risk_score': 0.4,
                'intervention': 'supportive',
                'resources': self.get_coping_resources()
            }
        
        return {
            'risk_level': 'low',
            'risk_score': 0.1,
            'intervention': 'none',
            'resources': []
        }
    
    def get_crisis_resources(self):
        return [
            "🚨 IMMEDIATE HELP: Call 988 (Suicide & Crisis Lifeline)",
            "📱 Text HOME to 741741 (Crisis Text Line)",
            "🌐 suicidepreventionlifeline.org",
            "If in immediate danger, call 911"
        ]
    
    def get_support_resources(self):
        return [
            "📞 Call 988 for confidential support",
            "💬 Text TEEN to 839863 (Teen Line)",
            "🌐 nami.org for mental health information",
            "Consider talking to a trusted adult"
        ]
    
    def get_coping_resources(self):
        return [
            "🧘 Try deep breathing: 4 counts in, 6 counts out",
            "📝 Journaling can help process feelings",
            "🚶 Physical activity can reduce stress",
            "💤 Ensure you're getting enough sleep"
        ]
