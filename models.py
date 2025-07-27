
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid
from cryptography.fernet import Fernet
import os
import json

db = SQLAlchemy()

class UserSession(db.Model):
    __tablename__ = 'user_sessions'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_active = db.Column(db.DateTime, default=datetime.utcnow)
    conversation_count = db.Column(db.Integer, default=0)
    risk_level = db.Column(db.String(20), default='low')
    
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

# New models for enhanced features

class SelfAssessmentEntry(db.Model):
    __tablename__ = 'self_assessment_entries'
    
    id = db.Column(db.Integer, primary_key=True)
    user_session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    questions_and_answers = db.Column(db.JSON)  # Store Q&A as JSON
    raw_score = db.Column(db.Float, nullable=True)
    summary_data = db.Column(db.JSON, nullable=True)  # Store assessment summary
    ai_feedback = db.Column(db.Text, nullable=True)  # Store AI-generated feedback
    
    # Relationship
    user_session = db.relationship('UserSession', backref='assessments')

class GamifiedTask(db.Model):
    __tablename__ = 'gamified_tasks'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=False)
    points = db.Column(db.Integer, default=10)
    task_type = db.Column(db.String(50), nullable=False)  # 'stress_management', 'mindfulness', 'journaling'
    is_recurring = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class UserTaskCompletion(db.Model):
    __tablename__ = 'user_task_completions'
    
    id = db.Column(db.Integer, primary_key=True)
    user_session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    task_id = db.Column(db.Integer, db.ForeignKey('gamified_tasks.id'))
    completion_timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    earned_points = db.Column(db.Integer, default=0)
    
    # Relationships
    user_session = db.relationship('UserSession', backref='task_completions')
    task = db.relationship('GamifiedTask', backref='completions')

class UserProgressPost(db.Model):
    __tablename__ = 'user_progress_posts'
    
    id = db.Column(db.Integer, primary_key=True)
    user_session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    anonymized_progress_summary = db.Column(db.JSON)  # Store progress data as JSON
    shared_text = db.Column(db.Text, nullable=True)  # Optional user comment
    privacy_setting = db.Column(db.String(20), default='public')  # 'public', 'private'
    
    # Relationship
    user_session = db.relationship('UserSession', backref='progress_posts')

class PersonalizedFeedback(db.Model):
    __tablename__ = 'personalized_feedback'
    
    id = db.Column(db.Integer, primary_key=True)
    user_session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    assessment_id = db.Column(db.Integer, db.ForeignKey('self_assessment_entries.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    feedback_content = db.Column(db.Text, nullable=False)
    feedback_type = db.Column(db.String(50), nullable=False)  # 'assessment', 'progress', 'general'
    ai_provider = db.Column(db.String(20), nullable=False)  # 'gemini', 'openai', 'perplexity'
    
    # Relationships
    user_session = db.relationship('UserSession', backref='feedback')
    assessment = db.relationship('SelfAssessmentEntry', backref='feedback')
