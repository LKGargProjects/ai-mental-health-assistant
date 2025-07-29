"""
AI Mental Health Assistant - Flask Backend
Optimized for performance and maintainability
"""

import os
import json
import uuid
import redis
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

from flask import Flask, request, jsonify, session, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
from flask_session import Session
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import after environment setup
from providers.gemini import get_gemini_response
from providers.perplexity import get_perplexity_response
from providers.openai import get_openai_response
from models import db, UserSession, Message, ConversationLog, CrisisEvent, SelfAssessmentEntry
from crisis_detection import detect_crisis_level

# Configuration constants
class Config:
    """Centralized configuration management"""
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-key-change-in-prod')
    ENVIRONMENT = os.environ.get('ENVIRONMENT', 'local')
    AI_PROVIDER = os.environ.get('AI_PROVIDER', 'gemini')
    PORT = int(os.environ.get('PORT', 5055))
    
    # Database configuration
    DATABASE_URL = os.environ.get('DATABASE_URL')
    if DATABASE_URL and DATABASE_URL.strip() and DATABASE_URL != 'port':
        if DATABASE_URL.startswith('postgresql://'):
            DATABASE_URL = DATABASE_URL.replace('postgresql://', 'postgresql+psycopg://')
        SQLALCHEMY_DATABASE_URI = DATABASE_URL
    else:
        SQLALCHEMY_DATABASE_URI = 'sqlite:///mental_health.db'
    
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Redis configuration
    REDIS_URL = os.environ.get('REDIS_URL')
    
    # CORS origins
    CORS_ORIGINS = [
        "http://localhost:8080", 
        "http://127.0.0.1:8080", 
        "http://localhost:3000",
        "http://localhost:9100",
        "http://127.0.0.1:9100",
        "https://ai-mental-health-assistant-tddc.onrender.com",
        "https://*.onrender.com"
    ]

def create_app() -> Flask:
    """Application factory pattern for better testing and modularity"""
    app = Flask(__name__, static_folder='ai_buddy_web/build/web', static_url_path='')
    app.config.from_object(Config)
    
    # Initialize extensions
    _init_extensions(app)
    
    # Register routes
    _register_routes(app)
    
    return app

def _init_extensions(app: Flask) -> None:
    """Initialize Flask extensions with proper error handling"""
    try:
        # Initialize database
        db.init_app(app)
        
        # Initialize session management
        _setup_session(app)
        
        # Initialize rate limiter
        _setup_rate_limiter(app)
        
        # Setup CORS
        _setup_cors(app)
        
        app.logger.info("All extensions initialized successfully")
        
    except Exception as e:
        app.logger.error(f"Failed to initialize extensions: {e}")
        raise

def _setup_session(app: Flask) -> None:
    """Configure session management with Redis fallback"""
    redis_url = app.config.get('REDIS_URL')
    
    if redis_url and redis_url != 'port' and redis_url.strip():
        try:
            redis_client = redis.from_url(redis_url)
            redis_client.ping()
            app.config['SESSION_TYPE'] = 'redis'
            app.config['SESSION_REDIS'] = redis_client
            app.logger.info("Redis sessions enabled")
        except Exception as e:
            app.logger.warning(f"Redis connection failed: {e}, using filesystem sessions")
            app.config['SESSION_TYPE'] = 'filesystem'
            app.config['SESSION_REDIS'] = None
    else:
        app.logger.info("No REDIS_URL found, using filesystem sessions")
        app.config['SESSION_TYPE'] = 'filesystem'
        app.config['SESSION_REDIS'] = None
    
    app.config['SESSION_PERMANENT'] = False
    app.config['SESSION_USE_SIGNER'] = False
    
    Session(app)

def _setup_rate_limiter(app: Flask) -> Limiter:
    """Configure rate limiting"""
    return Limiter(
        key_func=get_remote_address,
        app=app,
        default_limits=["500 per day", "100 per hour"],
        storage_uri=app.config.get('REDIS_URL', 'memory://')
    )

def _setup_cors(app: Flask) -> None:
    """Configure CORS with security best practices"""
    CORS(app, 
         origins=app.config.get('CORS_ORIGINS', []),
         supports_credentials=True,
         allow_headers=["Content-Type", "Authorization", "X-Session-ID", "Accept"],
         methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
         expose_headers=["Content-Type", "X-Session-ID"])

def _register_routes(app: Flask) -> None:
    """Register all application routes"""
    
    @app.before_request
    def ensure_session_id_is_str():
        """Ensure session ID is always a string for consistency"""
        session_id = request.headers.get('X-Session-ID')
        if session_id and not isinstance(session_id, str):
            request.headers = request.headers.copy()
            request.headers['X-Session-ID'] = str(session_id)

    @app.route("/", methods=["GET"])
    def index():
        """Serve the Flutter web app or fallback page"""
        app.logger.info(f"Root route called. Static folder: {app.static_folder}")
        
        if os.path.exists(app.static_folder) and os.path.exists(os.path.join(app.static_folder, 'index.html')):
            return send_from_directory(app.static_folder, 'index.html')
        else:
            return _get_fallback_html(app)

    @app.route("/api/health", methods=["GET"])
    def health():
        """Enhanced health check endpoint"""
        try:
            # Check database connection
            db_status = _check_database_health()
            
            # Check Redis connection
            redis_status = _check_redis_health()
            
            health_data = {
                "status": "healthy",
                "timestamp": datetime.utcnow().isoformat(),
                "environment": app.config.get('ENVIRONMENT'),
                "port": app.config.get('PORT'),
                "provider": app.config.get('AI_PROVIDER'),
                "database": db_status,
                "redis": redis_status,
                "cors_enabled": True,
                "cors_origins": app.config.get('CORS_ORIGINS', []),
                "endpoints": [
                    "/api/health",
                    "/api/chat", 
                    "/api/get_or_create_session",
                    "/api/chat_history",
                    "/api/mood_history",
                    "/api/mood_entry",
                    "/api/self_assessment"
                ]
            }
            
            return jsonify(health_data), 200
            
        except Exception as e:
            app.logger.error(f"Health check failed: {e}")
            return jsonify({"status": "unhealthy", "error": str(e)}), 500

    @app.route("/api/chat", methods=["POST"])
    @app.limiter.limit("30 per minute")
    def chat():
        """Enhanced chat endpoint with better error handling"""
        try:
            data = request.get_json()
            if not data or 'message' not in data:
                return jsonify({"error": "Message is required"}), 400
            
            session_id = _get_or_create_session()
            user_message = data['message'].strip()
            
            if not user_message:
                return jsonify({"error": "Message cannot be empty"}), 400
            
            # Process message with AI provider
            ai_response, risk_level = _process_chat_message(user_message, session_id)
            
            return jsonify({
                "response": ai_response,
                "risk_level": risk_level,
                "session_id": session_id
            }), 200
            
        except Exception as e:
            app.logger.error(f"Chat endpoint error: {e}")
            return jsonify({"error": "Internal server error"}), 500

    # Additional routes...
    _register_additional_routes(app)

def _get_or_create_session() -> str:
    """Get or create user session with proper error handling"""
    session_id = request.headers.get('X-Session-ID')
    
    if not session_id:
        session_id = str(uuid.uuid4())
    
    try:
        # Check if session exists in database
        existing_session = UserSession.query.filter_by(session_id=session_id).first()
        if not existing_session:
            new_session = UserSession(session_id=session_id)
            db.session.add(new_session)
            db.session.commit()
            app.logger.info(f"Created new session: {session_id}")
        else:
            app.logger.info(f"Using existing session: {session_id}")
            
    except Exception as e:
        app.logger.error(f"Session management error: {e}")
        # Continue without database session if needed
    
    return session_id

def _process_chat_message(message: str, session_id: str) -> Tuple[str, str]:
    """Process chat message with AI provider and crisis detection"""
    try:
        # Get AI response based on configured provider
        provider = app.config.get('AI_PROVIDER', 'gemini')
        
        if provider == 'gemini':
            ai_response = get_gemini_response(message)
        elif provider == 'openai':
            ai_response = get_openai_response(message)
        elif provider == 'perplexity':
            ai_response = get_perplexity_response(message)
        else:
            ai_response = get_gemini_response(message)  # Default fallback
        
        # Detect crisis level
        risk_level = detect_crisis_level(message)
        
        # Log conversation
        _log_conversation(session_id, message, ai_response, risk_level)
        
        return ai_response, risk_level
        
    except Exception as e:
        app.logger.error(f"Message processing error: {e}")
        return "I'm having trouble processing your message right now. Please try again.", "low"

def _log_conversation(session_id: str, user_message: str, ai_response: str, risk_level: str) -> None:
    """Log conversation to database with error handling"""
    try:
        # Convert risk level to numeric score
        risk_score = _convert_risk_level_to_score(risk_level)
        
        conversation_log = ConversationLog(
            session_id=session_id,
            user_message=user_message,
            ai_response=ai_response,
            risk_level=risk_level,
            risk_score=risk_score,
            timestamp=datetime.utcnow()
        )
        
        db.session.add(conversation_log)
        db.session.commit()
        
    except Exception as e:
        app.logger.error(f"Failed to log conversation: {e}")

def _convert_risk_level_to_score(risk_level: str) -> float:
    """Convert risk level string to numeric score"""
    risk_mapping = {
        'low': 0.0,
        'medium': 0.5,
        'high': 0.8,
        'crisis': 1.0
    }
    return risk_mapping.get(risk_level.lower(), 0.0)

def _check_database_health() -> str:
    """Check database connection health"""
    try:
        db.session.execute(text("SELECT 1"))
        return "healthy"
    except Exception as e:
        return f"unhealthy: {str(e)}"

def _check_redis_health() -> str:
    """Check Redis connection health"""
    try:
        if app.config.get('SESSION_TYPE') == 'redis':
            redis_client = app.config.get('SESSION_REDIS')
            if redis_client:
                redis_client.ping()
                return "healthy"
            else:
                return "not configured"
        else:
            return "using filesystem"
    except Exception as e:
        return f"unhealthy: {str(e)}"

def _get_fallback_html(app: Flask) -> str:
    """Generate fallback HTML page"""
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>AI Mental Health Assistant</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            .container {{ max-width: 600px; margin: 0 auto; }}
            .api-link {{ display: block; margin: 10px 0; padding: 10px; background: #f0f0f0; text-decoration: none; color: #333; }}
            .api-link:hover {{ background: #e0e0e0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>AI Mental Health Assistant</h1>
            <p>The Flutter web app is not available. Here are the API endpoints:</p>
            <a href="/api/health" class="api-link">Health Check</a>
            <a href="/api/deploy-test" class="api-link">Deploy Test</a>
            <a href="/api/stats" class="api-link">Statistics</a>
            <p>Static folder: {app.static_folder}</p>
            <p>Static folder exists: {os.path.exists(app.static_folder)}</p>
            <p>Index.html exists: {os.path.exists(os.path.join(app.static_folder, 'index.html'))}</p>
        </div>
    </body>
    </html>
    """

def _register_additional_routes(app: Flask) -> None:
    """Register additional API routes"""
    
    @app.route("/api/get_or_create_session", methods=['GET'])
    def get_or_create_session_endpoint():
        """Get or create session endpoint"""
        session_id = _get_or_create_session()
        return jsonify({"session_id": session_id})

    @app.route('/api/chat_history', methods=['GET'])
    def get_chat_history():
        """Get chat history for current session"""
        session_id = request.headers.get('X-Session-ID')
        if not session_id:
            return jsonify([])
        
        try:
            messages = ConversationLog.query.filter_by(session_id=session_id).order_by(ConversationLog.timestamp.desc()).limit(50).all()
            return jsonify([{
                'user_message': msg.user_message,
                'ai_response': msg.ai_response,
                'risk_level': msg.risk_level,
                'timestamp': msg.timestamp.isoformat()
            } for msg in messages])
        except Exception as e:
            app.logger.error(f"Chat history error: {e}")
            return jsonify([])

    @app.route('/api/self_assessment', methods=['POST', 'GET'])
    def submit_self_assessment():
        """Handle self-assessment submissions"""
        if request.method == 'GET':
            return jsonify({"message": "Self-assessment endpoint ready"})
        
        try:
            data = request.get_json() or {}
            
            # Clean and validate data
            cleaned_data = {}
            required_fields = ['mood', 'energy', 'sleep', 'stress']
            
            for field in required_fields:
                value = data.get(field)
                if value is None or value == "" or str(value).lower() in ['null', 'none']:
                    return jsonify({"error": f"Missing required field: {field}"}), 400
                cleaned_data[field] = value.strip() if isinstance(value, str) else value
            
            # Optional fields
            optional_fields = ['notes', 'crisis_level', 'anxiety_level']
            for field in optional_fields:
                value = data.get(field)
                if value and value != "" and str(value).lower() not in ['null', 'none']:
                    cleaned_data[field] = value.strip() if isinstance(value, str) else value
            
            app.logger.info(f"Assessment data processed: {cleaned_data}")
            
            return jsonify({"message": "Assessment received", "success": True}), 201
            
        except Exception as e:
            app.logger.error(f"Self-assessment error: {e}")
            return jsonify({"error": "Failed to process assessment"}), 500

# Create the application instance
app = create_app()

if __name__ == '__main__':
    with app.app_context():
        try:
            db.create_all()
            app.logger.info("Database tables created successfully")
        except Exception as e:
            app.logger.error(f"Database initialization error: {e}")
    
    app.run(host='0.0.0.0', port=app.config.get('PORT', 5055), debug=False)
