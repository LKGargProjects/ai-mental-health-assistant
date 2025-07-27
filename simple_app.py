#!/usr/bin/env python3
"""
Simplified version of the enhanced mental health app for testing
"""

from flask import Flask, request, jsonify, session
from flask_sqlalchemy import SQLAlchemy
from flask_session import Session
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv
import os
import uuid
from datetime import datetime

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app, supports_credentials=True)

# Basic configuration
app.config['SECRET_KEY'] = 'test-key-change-in-prod'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mental_health.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SESSION_TYPE'] = 'filesystem'

# Initialize extensions
db = SQLAlchemy()
db.init_app(app)
Session(app)

# Rate limiting
limiter = Limiter(
    key_func=get_remote_address,
    app=app,
    default_limits=["100 per day", "20 per hour"],
    storage_uri="memory://"
)

# Simple models for testing
class UserSession(db.Model):
    __tablename__ = 'user_sessions'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_active = db.Column(db.DateTime, default=datetime.utcnow)

class SelfAssessmentEntry(db.Model):
    __tablename__ = 'self_assessment_entries'
    id = db.Column(db.Integer, primary_key=True)
    user_session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    questions_and_answers = db.Column(db.JSON)
    raw_score = db.Column(db.Float, nullable=True)
    ai_feedback = db.Column(db.Text, nullable=True)

class GamifiedTask(db.Model):
    __tablename__ = 'gamified_tasks'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=False)
    points = db.Column(db.Integer, default=10)
    task_type = db.Column(db.String(50), nullable=False)
    is_recurring = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)

class UserTaskCompletion(db.Model):
    __tablename__ = 'user_task_completions'
    id = db.Column(db.Integer, primary_key=True)
    user_session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    task_id = db.Column(db.Integer, db.ForeignKey('gamified_tasks.id'))
    completion_timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    earned_points = db.Column(db.Integer, default=0)

class UserProgressPost(db.Model):
    __tablename__ = 'user_progress_posts'
    id = db.Column(db.Integer, primary_key=True)
    user_session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    anonymized_progress_summary = db.Column(db.JSON)
    shared_text = db.Column(db.Text, nullable=True)
    privacy_setting = db.Column(db.String(20), default='public')

# Predefined data
ASSESSMENT_QUESTIONS = [
    {
        "id": 1,
        "question": "How often do you feel overwhelmed by daily tasks?",
        "type": "multiple_choice",
        "options": ["Never", "Rarely", "Sometimes", "Often", "Always"],
        "category": "stress"
    },
    {
        "id": 2,
        "question": "How would you rate your overall mood today?",
        "type": "scale",
        "min": 1,
        "max": 10,
        "category": "mood"
    }
]

DEFAULT_TASKS = [
    {
        "name": "Mindful Breathing",
        "description": "Take 5 deep breaths, focusing on your breath",
        "points": 10,
        "task_type": "mindfulness",
        "is_recurring": True
    },
    {
        "name": "Gratitude Journal",
        "description": "Write down 3 things you're grateful for today",
        "points": 15,
        "task_type": "journaling",
        "is_recurring": True
    }
]

def get_or_create_session():
    """Get or create anonymous user session"""
    session_id = session.get('session_id')
    
    if not session_id:
        session_id = str(uuid.uuid4())
        session['session_id'] = session_id
        
        try:
            user_session = UserSession(id=session_id)
            db.session.add(user_session)
            db.session.commit()
        except Exception as e:
            db.session.rollback()
    
    return session_id

@app.route("/")
def index():
    return jsonify({
        "status": "ok", 
        "message": "Enhanced AI Mental Health API is running"
    })

@app.route("/assessments/start", methods=["GET"])
def start_assessment():
    """Get assessment questions"""
    try:
        return jsonify({
            "questions": ASSESSMENT_QUESTIONS,
            "total_questions": len(ASSESSMENT_QUESTIONS)
        })
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/assessments/submit", methods=["POST"])
def submit_assessment():
    """Submit assessment responses"""
    try:
        data = request.get_json()
        if not data or 'responses' not in data:
            return jsonify({"error": "No responses provided"}), 400

        session_id = get_or_create_session()
        responses = data['responses']
        
        # Simple score calculation
        total_score = 0
        max_score = len(ASSESSMENT_QUESTIONS) * 5
        
        for response in responses:
            if response.get('type') == 'multiple_choice':
                options = response.get('options', [])
                selected = response.get('answer', '')
                if selected in options:
                    score = options.index(selected) + 1
                    total_score += score
            elif response.get('type') == 'scale':
                score = int(response.get('answer', 5))
                total_score += score
        
        normalized_score = (total_score / max_score) * 100 if max_score > 0 else 0
        
        # Create assessment entry
        assessment_entry = SelfAssessmentEntry(
            user_session_id=session_id,
            questions_and_answers=responses,
            raw_score=normalized_score,
            ai_feedback="Thank you for completing the assessment. Your responses help us understand your current mental health state."
        )
        db.session.add(assessment_entry)
        db.session.commit()
        
        return jsonify({
            "assessment_id": assessment_entry.id,
            "score": normalized_score,
            "feedback": assessment_entry.ai_feedback,
            "timestamp": assessment_entry.timestamp.isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/tasks", methods=["GET"])
def get_tasks():
    """Get available gamified tasks"""
    try:
        # Ensure default tasks exist
        existing_tasks = GamifiedTask.query.filter_by(is_active=True).all()
        if not existing_tasks:
            for task_data in DEFAULT_TASKS:
                task = GamifiedTask(**task_data)
                db.session.add(task)
            db.session.commit()
            existing_tasks = GamifiedTask.query.filter_by(is_active=True).all()
        
        tasks = []
        for task in existing_tasks:
            tasks.append({
                "id": task.id,
                "name": task.name,
                "description": task.description,
                "points": task.points,
                "task_type": task.task_type,
                "is_recurring": task.is_recurring
            })
        
        return jsonify({"tasks": tasks})
        
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/tasks/<int:task_id>/complete", methods=["POST"])
def complete_task(task_id):
    """Mark a task as completed"""
    try:
        session_id = get_or_create_session()
        
        task = GamifiedTask.query.get(task_id)
        if not task:
            return jsonify({"error": "Task not found"}), 404
        
        # Create completion record
        completion = UserTaskCompletion(
            user_session_id=session_id,
            task_id=task_id,
            earned_points=task.points
        )
        db.session.add(completion)
        db.session.commit()
        
        return jsonify({
            "task_id": task_id,
            "points_earned": task.points,
            "completion_timestamp": completion.completion_timestamp.isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/reminders", methods=["GET"])
def get_reminders():
    """Get task reminders"""
    try:
        session_id = get_or_create_session()
        
        # Get available tasks
        available_tasks = GamifiedTask.query.filter_by(is_active=True).all()
        
        reminders = []
        for task in available_tasks:
            reminders.append({
                "task_id": task.id,
                "name": task.name,
                "description": task.description,
                "points": task.points,
                "task_type": task.task_type,
                "is_recurring": task.is_recurring
            })
        
        return jsonify({"reminders": reminders})
        
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/progress/share", methods=["POST"])
def share_progress():
    """Share user progress"""
    try:
        data = request.get_json()
        session_id = get_or_create_session()
        
        # Create progress summary
        progress_summary = {
            "assessment_count": 1,
            "task_completions": 1,
            "total_points_earned": 10,
            "last_assessment_score": 75.0
        }
        
        # Create progress post
        progress_post = UserProgressPost(
            user_session_id=session_id,
            anonymized_progress_summary=progress_summary,
            shared_text=data.get('shared_text'),
            privacy_setting=data.get('privacy_setting', 'public')
        )
        db.session.add(progress_post)
        db.session.commit()
        
        return jsonify({
            "post_id": progress_post.id,
            "timestamp": progress_post.timestamp.isoformat(),
            "message": "Progress shared successfully"
        })
        
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/community/feed", methods=["GET"])
def get_community_feed():
    """Get community feed"""
    try:
        public_posts = UserProgressPost.query.filter_by(
            privacy_setting='public'
        ).order_by(UserProgressPost.timestamp.desc()).limit(10).all()
        
        feed = []
        for post in public_posts:
            feed.append({
                "id": post.id,
                "timestamp": post.timestamp.isoformat(),
                "progress_summary": post.anonymized_progress_summary,
                "shared_text": post.shared_text
            })
        
        return jsonify({"feed": feed})
        
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/assessments/history", methods=["GET"])
def get_assessment_history():
    """Get assessment history"""
    try:
        session_id = get_or_create_session()
        
        assessments = SelfAssessmentEntry.query.filter_by(
            user_session_id=session_id
        ).order_by(SelfAssessmentEntry.timestamp.desc()).all()
        
        history = []
        for assessment in assessments:
            history.append({
                "id": assessment.id,
                "timestamp": assessment.timestamp.isoformat(),
                "score": assessment.raw_score,
                "feedback": assessment.ai_feedback
            })
        
        return jsonify({"history": history})
        
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/stats", methods=["GET"])
def stats():
    """Get platform stats"""
    try:
        return jsonify({
            "total_sessions": UserSession.query.count(),
            "total_assessments": SelfAssessmentEntry.query.count(),
            "total_task_completions": UserTaskCompletion.query.count(),
            "total_progress_posts": UserProgressPost.query.count()
        })
    except Exception as e:
        return jsonify({"error": f"Error: {str(e)}"}), 500

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    
    port = int(os.environ.get("PORT", 5053))
    app.run(host="0.0.0.0", port=port, debug=False) 