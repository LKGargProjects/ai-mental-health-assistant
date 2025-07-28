
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid
import os

db = SQLAlchemy()

class UserSession(db.Model):
    __tablename__ = 'user_sessions'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_active = db.Column(db.DateTime, default=datetime.utcnow)
    conversation_count = db.Column(db.Integer, default=0)
    risk_level = db.Column(db.String(20), default='low')
    
class Message(db.Model):
    __tablename__ = 'messages'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    content = db.Column(db.Text, nullable=False)
    is_user = db.Column(db.Boolean, default=False)  # True for user, False for AI
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    risk_level = db.Column(db.String(20), default='none')
    resources = db.Column(db.Text)  # JSON string for crisis resources
    
class ConversationLog(db.Model):
    __tablename__ = 'conversation_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    provider = db.Column(db.String(20))
    risk_score = db.Column(db.Float, default=0.0)
    
class CrisisEvent(db.Model):
    __tablename__ = 'crisis_events'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    risk_level = db.Column(db.String(20))
    intervention_taken = db.Column(db.String(100))
    escalated = db.Column(db.Boolean, default=False)
