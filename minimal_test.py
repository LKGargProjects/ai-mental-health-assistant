#!/usr/bin/env python3
"""
Minimal test to check server startup
"""

import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_imports():
    """Test all imports"""
    try:
        print("Testing imports...")
        
        # Test basic Flask imports
        from flask import Flask, request, jsonify, session
        print("✅ Flask imports OK")
        
        # Test SQLAlchemy
        from flask_sqlalchemy import SQLAlchemy
        print("✅ SQLAlchemy import OK")
        
        # Test session
        from flask_session import Session
        print("✅ Flask-Session import OK")
        
        # Test CORS
        from flask_cors import CORS
        print("✅ Flask-CORS import OK")
        
        # Test limiter
        from flask_limiter import Limiter
        from flask_limiter.util import get_remote_address
        print("✅ Flask-Limiter import OK")
        
        # Test models
        from models import db, UserSession, ConversationLog, CrisisEvent
        print("✅ Basic models import OK")
        
        # Test enhanced models
        from models import SelfAssessmentEntry, GamifiedTask, UserTaskCompletion, UserProgressPost, PersonalizedFeedback
        print("✅ Enhanced models import OK")
        
        # Test providers
        from providers.gemini import get_gemini_response
        from providers.perplexity import get_perplexity_response
        from providers.openai import get_openai_response
        print("✅ Providers import OK")
        
        # Test crisis detection
        from crisis_detection import detect_crisis_level
        print("✅ Crisis detection import OK")
        
        print("✅ All imports successful!")
        return True
        
    except Exception as e:
        print(f"❌ Import error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_basic_app():
    """Test basic app creation"""
    try:
        print("\nTesting basic app creation...")
        
        from flask import Flask
        from flask_sqlalchemy import SQLAlchemy
        from flask_session import Session
        from flask_cors import CORS
        from flask_limiter import Limiter
        from flask_limiter.util import get_remote_address
        
        app = Flask(__name__)
        
        # Basic config
        app.config['SECRET_KEY'] = 'test-key'
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///test.db'
        app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
        app.config['SESSION_TYPE'] = 'filesystem'
        
        # Initialize extensions
        db = SQLAlchemy()
        db.init_app(app)
        Session(app)
        CORS(app)
        Limiter(
            key_func=get_remote_address,
            app=app,
            default_limits=["100 per day", "20 per hour"],
            storage_uri="memory://"
        )
        
        print("✅ Basic app creation successful!")
        return True
        
    except Exception as e:
        print(f"❌ App creation error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🧪 Testing Enhanced Mental Health Platform Setup")
    print("=" * 50)
    
    # Test imports
    imports_ok = test_imports()
    
    # Test basic app
    app_ok = test_basic_app()
    
    print("\n" + "=" * 50)
    if imports_ok and app_ok:
        print("✅ All tests passed! Platform setup is correct.")
    else:
        print("❌ Some tests failed. Check the errors above.") 