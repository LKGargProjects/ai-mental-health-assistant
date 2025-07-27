#!/usr/bin/env python3
"""
Simple database test script
"""

import os
from dotenv import load_dotenv
from flask import Flask
from flask_sqlalchemy import SQLAlchemy

# Load environment variables
load_dotenv()

# Create Flask app
app = Flask(__name__)

# Database configuration
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mental_health.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize SQLAlchemy
db = SQLAlchemy()

# Import models
from models import UserSession, ConversationLog, CrisisEvent, SelfAssessmentEntry, GamifiedTask, UserTaskCompletion, UserProgressPost, PersonalizedFeedback

# Initialize app
db.init_app(app)

def test_database():
    """Test database initialization"""
    try:
        with app.app_context():
            print("Creating database tables...")
            db.create_all()
            print("✅ Database tables created successfully!")
            
            # Test basic operations
            print("Testing basic database operations...")
            
            # Test UserSession
            session = UserSession()
            db.session.add(session)
            db.session.commit()
            print(f"✅ UserSession created: {session.id}")
            
            # Test GamifiedTask
            task = GamifiedTask(
                name="Test Task",
                description="Test task description",
                points=10,
                task_type="test",
                is_recurring=False
            )
            db.session.add(task)
            db.session.commit()
            print(f"✅ GamifiedTask created: {task.id}")
            
            # Clean up
            db.session.delete(session)
            db.session.delete(task)
            db.session.commit()
            print("✅ Test data cleaned up")
            
            return True
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False

if __name__ == "__main__":
    test_database() 