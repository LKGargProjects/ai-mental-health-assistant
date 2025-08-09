"""
AI Mental Health Assistant - Flask Backend
Optimized for single codebase usage across development, Docker, and Render production
"""

import os
import json
import uuid
import redis
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Tuple, List

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
import requests

# Geography-specific crisis resources
CRISIS_RESOURCES_BY_COUNTRY = {
    'in': {  # India
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call iCall Helpline at 022-25521111 or AASRA at 91-22-27546669. You can also text HOME to 741741 to reach Crisis Text Line. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'iCall Helpline', 'number': '022-25521111', 'available': '24/7'},
            {'name': 'AASRA', 'number': '91-22-27546669', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'}
        ]
    },
    'us': {  # United States
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call the National Suicide Prevention Lifeline at 988 or text HOME to 741741 to reach the Crisis Text Line. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'National Suicide Prevention Lifeline', 'number': '988', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '911', 'available': '24/7'}
        ]
    },
    'uk': {  # United Kingdom
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call Samaritans at 116 123 or text SHOUT to 85258. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'Samaritans', 'number': '116 123', 'available': '24/7'},
            {'name': 'SHOUT Text Line', 'text': 'SHOUT to 85258', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '999', 'available': '24/7'}
        ]
    },
    'ca': {  # Canada
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call the National Suicide Prevention Service at 1-833-456-4566 or text HOME to 741741. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'National Suicide Prevention Service', 'number': '1-833-456-4566', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '911', 'available': '24/7'}
        ]
    },
    'au': {  # Australia
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call Lifeline at 13 11 14 or text HOME to 741741. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'Lifeline', 'number': '13 11 14', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '000', 'available': '24/7'}
        ]
    },
    'de': {  # Germany
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call TelefonSeelsorge at 0800 111 0 111 or text HOME to 741741. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'TelefonSeelsorge', 'number': '0800 111 0 111', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '112', 'available': '24/7'}
        ]
    },
    'fr': {  # France
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call SOS Amitié at 09 72 39 40 50 or text HOME to 741741. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'SOS Amitié', 'number': '09 72 39 40 50', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '112', 'available': '24/7'}
        ]
    },
    'jp': {  # Japan
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call TELL Lifeline at 03-5774-0992 or text HOME to 741741. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'TELL Lifeline', 'number': '03-5774-0992', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '119', 'available': '24/7'}
        ]
    },
    'br': {  # Brazil
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call CVV at 188 or text HOME to 741741. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'CVV', 'number': '188', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '192', 'available': '24/7'}
        ]
    },
    'mx': {  # Mexico
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please call SAPTEL at 55-5259-8121 or text HOME to 741741. You're not alone, and help is available 24/7.",
        'crisis_numbers': [
            {'name': 'SAPTEL', 'number': '55-5259-8121', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'number': '911', 'available': '24/7'}
        ]
    },
    'generic': {  # Fallback for unsupported countries
        'crisis_msg': "I'm very concerned about what you're sharing. This is a crisis situation and you need immediate help. Please reach out to Befrienders Worldwide or call your local emergency services. You can also text HOME to 741741 for international crisis support. You're not alone, and help is available.",
        'crisis_numbers': [
            {'name': 'Befrienders Worldwide', 'url': 'https://www.befrienders.org/', 'available': '24/7'},
            {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
            {'name': 'Emergency Services', 'note': 'Call your local emergency number', 'available': '24/7'}
        ]
    }
}

def get_country_code_from_ip(ip: str) -> str:
    """Get country code from IP address using ipinfo.io"""
    try:
        # Skip local/private IPs
        if ip in ['127.0.0.1', 'localhost', '::1'] or ip.startswith(('10.', '172.', '192.168.')):
            return 'generic'
        
        # Use ipinfo.io for geolocation
        response = requests.get(f'https://ipinfo.io/{ip}/json', timeout=5)
        if response.status_code == 200:
            data = response.json()
            country_code = data.get('country', '').lower()
            return country_code if country_code in CRISIS_RESOURCES_BY_COUNTRY else 'generic'
        else:
            return 'generic'
    except Exception as e:
        print(f"IP geolocation error: {e}")
        return 'generic'

def get_country_from_request(req) -> str:
    """Get country from request - either from country parameter or IP"""
    # Check for explicit country override
    data = req.get_json() if req.is_json else {}
    country = data.get('country', '').lower()
    
    if country and country in CRISIS_RESOURCES_BY_COUNTRY:
        return country
    
    # Get IP from various headers
    ip = req.headers.get('X-Forwarded-For', '').split(',')[0].strip()
    if not ip:
        ip = req.headers.get('X-Real-IP', '')
    if not ip:
        ip = req.remote_addr
    
    return get_country_code_from_ip(ip)

def _detect_environment() -> str:
    """Detect current environment automatically for single codebase usage"""
    if os.environ.get('RENDER'):
        return 'production'
    elif os.environ.get('DOCKER_ENV') or os.environ.get('DOCKER'):
        return 'docker'
    elif os.environ.get('ENVIRONMENT'):
        return os.environ.get('ENVIRONMENT')
    else:
        return 'local'

def _get_environment_config(environment: str) -> Dict[str, Any]:
    """Get environment-specific configuration for single codebase usage"""
    configs = {
        'local': {
            'port': 5055,
            'database_url': 'postgresql+psycopg://ai_buddy:ai_buddy_password@localhost:5432/mental_health',
            'redis_url': 'redis://localhost:6379',
            'cors_origins': [
                'http://localhost:8080', 
                'http://127.0.0.1:8080',
                'http://localhost:3000',
                'http://localhost:9100',
                'http://127.0.0.1:9100'
            ],
        },
        'docker': {
            'port': 5055,
            'database_url': 'postgresql+psycopg://ai_buddy:ai_buddy_password@db:5432/mental_health',
            'redis_url': 'redis://redis:6379',
            'cors_origins': [
                'http://localhost:8080', 
                'http://127.0.0.1:8080',
                'http://localhost:3000',
                'http://localhost:9100',
                'http://127.0.0.1:9100',
                'http://localhost:57442',
                'http://localhost:55725'
            ],
        },
        'production': {
            'port': 10000,
            'database_url': os.environ.get('DATABASE_URL'),
            'redis_url': 'redis://localhost:6379',
            'cors_origins': [
                'https://ai-mental-health-assistant-tddc.onrender.com',
                'https://*.onrender.com',
                'https://ai-mental-health-backend.onrender.com'
            ],
        }
    }
    return configs.get(environment, configs['local'])

# Configuration constants with environment detection
ENVIRONMENT = _detect_environment()
ENV_CONFIG = _get_environment_config(ENVIRONMENT)

class Config:
    """Configuration class for single codebase usage"""
    
    # Environment detection
    ENVIRONMENT = os.getenv('ENVIRONMENT', 'local')
    RENDER = os.getenv('RENDER', 'false').lower() == 'true'
    DOCKER_ENV = os.getenv('DOCKER_ENV', 'false').lower() == 'true'
    
    # Database configuration
    if RENDER:
        # Production (Render) configuration
        DATABASE_URL = os.getenv('DATABASE_URL')
        if DATABASE_URL and DATABASE_URL.startswith('postgres://'):
            DATABASE_URL = DATABASE_URL.replace('postgres://', 'postgresql://', 1)
    elif DOCKER_ENV:
        # Docker environment
        DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://ai_buddy:ai_buddy_password@db:5432/mental_health')
    else:
        # Local development
        DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://ai_buddy:ai_buddy_password@localhost:5432/mental_health')
    
    # Redis configuration
    if RENDER:
        REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
    elif DOCKER_ENV:
        REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379')
    else:
        REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
    
    # Flask configuration
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    SESSION_TYPE = os.getenv('SESSION_TYPE', 'redis')
    
    # Server configuration
    PORT = int(os.getenv('PORT', 5055))
    BACKEND_PORT = int(os.getenv('BACKEND_PORT', 5055))
    
    # AI Provider configuration
    GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
    OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
    PPLX_API_KEY = os.getenv('PPLX_API_KEY')
    AI_PROVIDER = os.getenv('AI_PROVIDER', 'gemini')
    
    # CORS configuration
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', 'http://localhost:8080,http://localhost:3000').split(',')
    
    # Rate limiting
    RATE_LIMIT_ENABLED = os.getenv('RATE_LIMIT_ENABLED', 'true').lower() == 'true'
    RATE_LIMIT_REQUESTS = int(os.getenv('RATE_LIMIT_REQUESTS', 30))
    RATE_LIMIT_WINDOW = int(os.getenv('RATE_LIMIT_WINDOW', 60))
    
    # Logging
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    
    # Version and build info
    VERSION = os.getenv('VERSION', '1.0.0')
    BUILD_TIME = os.getenv('BUILD_TIME', 'unknown')

def create_app() -> Flask:
    """Application factory pattern for single codebase usage"""
    app = Flask(__name__, static_folder='static', static_url_path='')
    
    # Load configuration
    app.config.from_object(Config)
    
    # Set SQLAlchemy database URI with explicit psycopg driver
    if Config.DATABASE_URL:
        # Force use of psycopg driver
        if 'postgresql://' in Config.DATABASE_URL and 'psycopg' not in Config.DATABASE_URL:
            Config.DATABASE_URL = Config.DATABASE_URL.replace('postgresql://', 'postgresql+psycopg://')
        app.config['SQLALCHEMY_DATABASE_URI'] = Config.DATABASE_URL
    else:
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mental_health.db'
    
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    
    # Initialize extensions
    _init_extensions(app)
    
    # Initialize database tables
    _init_database(app)
    
    # Register routes
    _register_routes(app)
    _register_additional_routes(app)
    
    return app

def _init_database(app: Flask) -> None:
    """Initialize database with tables"""
    with app.app_context():
        try:
            # Create tables if they don't exist
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id VARCHAR(255) PRIMARY KEY,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS chat_messages (
                    id SERIAL PRIMARY KEY,
                    session_id VARCHAR(255) REFERENCES sessions(id),
                    content TEXT NOT NULL,
                    is_user BOOLEAN NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    message_type VARCHAR(50) DEFAULT 'text'
                )
            """))
            
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS mood_entries (
                    id SERIAL PRIMARY KEY,
                    session_id VARCHAR(255) REFERENCES sessions(id),
                    mood_level INTEGER NOT NULL CHECK (mood_level >= 1 AND mood_level <= 5),
                    note TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS self_assessments (
                    id SERIAL PRIMARY KEY,
                    session_id VARCHAR(255) REFERENCES sessions(id),
                    mood INTEGER,
                    energy INTEGER,
                    sleep INTEGER,
                    stress INTEGER,
                    social INTEGER,
                    work INTEGER,
                    notes TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS crisis_detections (
                    id SERIAL PRIMARY KEY,
                    session_id VARCHAR(255) REFERENCES sessions(id),
                    message TEXT NOT NULL,
                    risk_level VARCHAR(50) NOT NULL,
                    risk_score DECIMAL(3,2) NOT NULL,
                    keywords TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            db.session.commit()
            app.logger.info("Database tables initialized successfully")
            
        except Exception as e:
            app.logger.error(f"Database initialization error: {e}")
            db.session.rollback()
            raise


def _init_extensions(app: Flask) -> None:
    """Initialize Flask extensions with proper error handling"""
    try:
        # Initialize database
        db.init_app(app)
        
        # Initialize session management
        _setup_session(app)
        
        # Initialize rate limiter
        app.limiter = _setup_rate_limiter(app)
        
        # Setup CORS
        _setup_cors(app)
        
        app.logger.info(f"All extensions initialized successfully for environment: {app.config.get('ENVIRONMENT')}")
        
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
         origins="*",
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
        app.logger.info(f"Root route called. Environment: {app.config.get('ENVIRONMENT')}")
        
        if os.path.exists(app.static_folder) and os.path.exists(os.path.join(app.static_folder, 'index.html')):
            return send_from_directory(app.static_folder, 'index.html')
        else:
            return _get_fallback_html(app)
    
    @app.route("/<path:filename>")
    def serve_static(filename):
        """Serve static files for Flutter web app"""
        if os.path.exists(os.path.join(app.static_folder, filename)):
            return send_from_directory(app.static_folder, filename)
        else:
            # Fallback to index.html for SPA routing
            return send_from_directory(app.static_folder, 'index.html')

    @app.route("/api/health", methods=["GET"])
    @app.limiter.exempt
    def health():
        """Enhanced health check endpoint with environment info"""
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
                "deployment": {
                    "platform": _detect_platform(),
                    "environment": app.config.get('ENVIRONMENT'),
                    "version": os.environ.get('VERSION', '1.0.0'),
                    "build_time": os.environ.get('BUILD_TIME', datetime.utcnow().isoformat()),
                },
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
        """Enhanced chat endpoint with geography-specific crisis detection"""
        try:
            data = request.get_json()
            if not data or 'message' not in data:
                return jsonify({"error": "Message is required"}), 400
            
            session_id = _get_or_create_session()
            user_message = data['message'].strip()
            
            if not user_message:
                return jsonify({"error": "Message cannot be empty"}), 400
            
            # Get country from request
            country = get_country_from_request(request)
            
            # Process message with AI provider
            ai_response, risk_level = _process_chat_message(user_message, session_id)
            
            # Get geography-specific crisis data
            crisis_data = get_crisis_response_and_resources(risk_level, country)
            
            return jsonify({
                "response": ai_response,
                "risk_level": risk_level,
                "session_id": session_id,
                "crisis_msg": crisis_data['crisis_msg'],
                "crisis_numbers": crisis_data['crisis_numbers']
            }), 200
            
        except Exception as e:
            app.logger.error(f"Chat endpoint error: {e}")
            return jsonify({"error": "Internal server error"}), 500

    # Additional routes...
    # _register_additional_routes(app)  # Removed duplicate call

def _get_or_create_session() -> str:
    """Get or create user session with proper error handling"""
    session_id = request.headers.get('X-Session-ID')
    
    if not session_id:
        session_id = str(uuid.uuid4())
    
    try:
        # Check if session exists in database
        existing_session = db.session.execute(
            text("SELECT id FROM sessions WHERE id = :session_id"),
            {'session_id': session_id}
        ).fetchone()
        
        if not existing_session:
            # Create new session in database
            db.session.execute(
                text("INSERT INTO sessions (id, created_at, last_activity) VALUES (:session_id, NOW(), NOW())"),
                {'session_id': session_id}
            )
            db.session.commit()
            # Use current_app for logging in request context
            from flask import current_app
            current_app.logger.info(f"Created new session: {session_id}")
        else:
            # Update last activity
            db.session.execute(
                text("UPDATE sessions SET last_activity = NOW() WHERE id = :session_id"),
                {'session_id': session_id}
            )
            db.session.commit()
            # Use current_app for logging in request context
            from flask import current_app
            current_app.logger.info(f"Using existing session: {session_id}")
            
    except Exception as e:
        # Use current_app for logging in request context
        from flask import current_app
        current_app.logger.error(f"Session management error: {e}")
        # Continue without database session if needed
    
    return session_id

def _process_chat_message(message: str, session_id: str) -> Tuple[str, str]:
    """Process chat message with AI provider and crisis detection"""
    try:
        # Detect crisis level FIRST
        risk_level = detect_crisis_level(message)
        
        # Get AI response based on configured provider, passing crisis level
        from flask import current_app
        provider = current_app.config.get('AI_PROVIDER', 'gemini')
        
        if provider == 'gemini':
            ai_response = get_gemini_response(message, session_id=session_id, risk_level=risk_level)
        elif provider == 'openai':
            ai_response = get_openai_response(message, risk_level=risk_level)
        elif provider == 'perplexity':
            ai_response = get_perplexity_response(message, risk_level=risk_level)
        else:
            ai_response = get_gemini_response(message, session_id=session_id, risk_level=risk_level)  # Default fallback

        # Log conversation
        _log_conversation(session_id, message, ai_response, risk_level)
        
        return ai_response, risk_level
        
    except Exception as e:
        # Use current_app for logging in request context
        from flask import current_app
        current_app.logger.error(f"Message processing error: {e}")
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
        # Use current_app for logging in request context
        from flask import current_app
        current_app.logger.error(f"Failed to log conversation: {e}")

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
        from flask import current_app
        if current_app.config.get('SESSION_TYPE') == 'redis':
            redis_client = current_app.config.get('SESSION_REDIS')
            if redis_client:
                redis_client.ping()
                return "healthy"
            else:
                return "not configured"
        else:
            return "using filesystem"
    except Exception as e:
        return f"unhealthy: {str(e)}"

def _detect_platform() -> str:
    """Detect deployment platform for single codebase usage"""
    if os.environ.get('RENDER'):
        return 'render'
    elif os.environ.get('DOCKER_ENV') or os.environ.get('DOCKER'):
        return 'docker'
    else:
        return 'local'

def _get_fallback_html(app: Flask) -> str:
    """Generate fallback HTML page with environment info"""
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
            .env-info {{ background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>AI Mental Health Assistant</h1>
            <div class="env-info">
                <h3>Environment Information</h3>
                <p><strong>Environment:</strong> {app.config.get('ENVIRONMENT')}</p>
                <p><strong>Platform:</strong> {_detect_platform()}</p>
                <p><strong>Port:</strong> {app.config.get('PORT')}</p>
                <p><strong>Static Folder:</strong> {app.static_folder}</p>
                <p><strong>Static Folder Exists:</strong> {os.path.exists(app.static_folder)}</p>
                <p><strong>Index.html Exists:</strong> {os.path.exists(os.path.join(app.static_folder, 'index.html'))}</p>
            </div>
            <p>The Flutter web app is not available. Here are the API endpoints:</p>
            <a href="/api/health" class="api-link">Health Check</a>
            <a href="/api/deploy-test" class="api-link">Deploy Test</a>
            <a href="/api/stats" class="api-link">Statistics</a>
        </div>
    </body>
    </html>
    """

def _enhanced_crisis_detection(message: str) -> Tuple[str, float, List[str]]:
    """Enhanced crisis detection with keyword analysis"""
    message_lower = message.lower()
    
    # Crisis keywords with weights
    crisis_keywords = {
        'suicide': 1.0, 'kill myself': 1.0, 'want to die': 1.0, 'end it all': 1.0,
        'take me from this earth': 1.0, 'take me from earth': 1.0, 'remove me from earth': 1.0,
        'self harm': 0.9, 'cut myself': 0.9, 'hurt myself': 0.9,
        'hopeless': 0.8, 'no hope': 0.8, 'worthless': 0.8, 'useless': 0.8,
        'depressed': 0.7, 'depression': 0.7, 'anxiety': 0.6, 'panic': 0.6,
        'lonely': 0.5, 'alone': 0.5, 'isolated': 0.5,
        'stress': 0.4, 'overwhelmed': 0.4, 'can\'t cope': 0.4
    }
    
    found_keywords = []
    total_score = 0.0
    
    for keyword, weight in crisis_keywords.items():
        if keyword in message_lower:
            found_keywords.append(keyword)
            total_score += weight
    
    # Normalize score
    max_possible_score = sum(crisis_keywords.values())
    normalized_score = total_score / max_possible_score if max_possible_score > 0 else 0
    
    # Determine risk level
    if normalized_score >= 0.8:
        risk_level = 'crisis'
    elif normalized_score >= 0.6:
        risk_level = 'high'
    elif normalized_score >= 0.4:
        risk_level = 'medium'
    else:
        risk_level = 'low'
    
    return risk_level, normalized_score, found_keywords


def get_crisis_response_and_resources(risk_level: str, country: str = 'generic') -> Dict[str, Any]:
    """Get geography-specific crisis response and resources"""
    if risk_level == 'crisis':
        # Get country-specific crisis resources
        country_resources = CRISIS_RESOURCES_BY_COUNTRY.get(country, CRISIS_RESOURCES_BY_COUNTRY['generic'])
        return {
            'crisis_msg': country_resources['crisis_msg'],
            'crisis_numbers': country_resources['crisis_numbers'],
            'risk_level': risk_level
        }
    else:
        # For non-crisis levels, return standard responses
        responses = {
            'high': "I'm worried about what you're experiencing. These feelings are serious and you deserve support. Please consider reaching out to a mental health professional or calling your local crisis helpline. You don't have to face this alone.",
            'medium': "I can see you're going through a difficult time. It's important to take these feelings seriously. Consider talking to someone you trust or reaching out to a mental health professional. You're showing strength by sharing this.",
            'low': "Thank you for sharing how you're feeling. It's normal to have difficult moments, and it's okay to not be okay. Consider reaching out to friends, family, or a mental health professional for support."
        }
        return {
            'crisis_msg': responses.get(risk_level, responses['low']),
            'crisis_numbers': [],
            'risk_level': risk_level
        }

def _get_crisis_response(risk_level: str, risk_score: float) -> str:
    """Get appropriate crisis response based on risk level (legacy function)"""
    if risk_level == 'crisis':
        return CRISIS_RESOURCES_BY_COUNTRY['generic']['crisis_msg']
    else:
        responses = {
            'high': "I'm worried about what you're experiencing. These feelings are serious and you deserve support. Please consider reaching out to a mental health professional or calling your local crisis helpline. You don't have to face this alone.",
            'medium': "I can see you're going through a difficult time. It's important to take these feelings seriously. Consider talking to someone you trust or reaching out to a mental health professional. You're showing strength by sharing this.",
            'low': "Thank you for sharing how you're feeling. It's normal to have difficult moments, and it's okay to not be okay. Consider reaching out to friends, family, or a mental health professional for support."
        }
        return responses.get(risk_level, responses['low'])


def _get_crisis_resources(risk_level: str) -> Dict[str, Any]:
    """Get crisis resources based on risk level"""
    resources = {
        'crisis': {
            'immediate': [
                {'name': 'National Suicide Prevention Lifeline', 'number': '988', 'available': '24/7'},
                {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'},
                {'name': 'Emergency Services', 'number': '911', 'available': '24/7'}
            ],
            'online': [
                {'name': 'Crisis Chat', 'url': 'https://www.crisischat.org/'},
                {'name': 'IMAlive', 'url': 'https://www.imalive.org/'}
            ]
        },
        'high': {
            'immediate': [
                {'name': 'National Suicide Prevention Lifeline', 'number': '988', 'available': '24/7'},
                {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'}
            ],
            'online': [
                {'name': 'Find a Therapist', 'url': 'https://www.psychologytoday.com/us/therapists'},
                {'name': 'Mental Health Resources', 'url': 'https://www.nami.org/help'}
            ]
        },
        'medium': {
            'immediate': [
                {'name': 'Crisis Text Line', 'text': 'HOME to 741741', 'available': '24/7'}
            ],
            'online': [
                {'name': 'Find a Therapist', 'url': 'https://www.psychologytoday.com/us/therapists'},
                {'name': 'Mental Health Resources', 'url': 'https://www.nami.org/help'}
            ]
        },
        'low': {
            'immediate': [],
            'online': [
                {'name': 'Mental Health Resources', 'url': 'https://www.nami.org/help'},
                {'name': 'Self-Care Tips', 'url': 'https://www.mind.org.uk/information-support/tips-for-everyday-living/'}
            ]
        }
    }
    return resources.get(risk_level, resources['low'])


def _get_personalized_recommendations(avg_mood: float, recent_entries: List) -> List[Dict[str, Any]]:
    """Get personalized wellness recommendations based on mood"""
    recommendations = []
    
    if avg_mood <= 2.0:
        # Low mood recommendations
        recommendations.extend([
            {
                'type': 'immediate',
                'title': 'Reach Out for Support',
                'description': 'Consider talking to a trusted friend, family member, or mental health professional.',
                'action': 'Call a friend or family member'
            },
            {
                'type': 'activity',
                'title': 'Gentle Physical Activity',
                'description': 'Even a short walk can help improve your mood and energy levels.',
                'action': 'Take a 10-minute walk outside'
            },
            {
                'type': 'self_care',
                'title': 'Practice Self-Compassion',
                'description': 'Be kind to yourself. It\'s okay to not be okay.',
                'action': 'Write down 3 things you\'re grateful for'
            }
        ])
    elif avg_mood <= 3.5:
        # Moderate mood recommendations
        recommendations.extend([
            {
                'type': 'activity',
                'title': 'Engage in Enjoyable Activities',
                'description': 'Do something you normally enjoy, even if you don\'t feel like it initially.',
                'action': 'Listen to your favorite music or watch a movie'
            },
            {
                'type': 'social',
                'title': 'Social Connection',
                'description': 'Connect with others, even if it\'s just a brief conversation.',
                'action': 'Send a message to a friend'
            },
            {
                'type': 'routine',
                'title': 'Maintain Daily Routine',
                'description': 'Stick to your regular schedule to provide structure and stability.',
                'action': 'Follow your usual daily routine'
            }
        ])
    else:
        # Good mood recommendations
        recommendations.extend([
            {
                'type': 'maintenance',
                'title': 'Maintain Positive Habits',
                'description': 'Keep up with activities that contribute to your well-being.',
                'action': 'Continue your current positive routines'
            },
            {
                'type': 'growth',
                'title': 'Personal Development',
                'description': 'Use your positive energy to work on personal goals.',
                'action': 'Set a small goal for the week'
            },
            {
                'type': 'gratitude',
                'title': 'Practice Gratitude',
                'description': 'Reflect on what\'s going well in your life.',
                'action': 'Write down 5 things you appreciate today'
            }
        ])
    
    return recommendations


def _get_default_recommendations() -> List[Dict[str, Any]]:
    """Get default wellness recommendations"""
    return [
        {
            'type': 'general',
            'title': 'Start with Small Steps',
            'description': 'Begin with simple activities that can improve your mood.',
            'action': 'Take a few deep breaths and stretch'
        },
        {
            'type': 'connection',
            'title': 'Reach Out',
            'description': 'Connect with someone you trust.',
            'action': 'Send a message to a friend or family member'
        },
        {
            'type': 'self_care',
            'title': 'Practice Self-Care',
            'description': 'Do something kind for yourself.',
            'action': 'Take a warm shower or bath'
        }
    ]


def _analyze_mood_pattern(entries: List) -> Dict[str, Any]:
    """Analyze mood patterns from recent entries"""
    if not entries:
        return {'pattern': 'insufficient_data', 'trend': 'unknown'}
    
    mood_levels = [entry.mood_level for entry in entries]
    
    # Calculate trend
    if len(mood_levels) >= 2:
        recent_avg = sum(mood_levels[:3]) / min(3, len(mood_levels))
        older_avg = sum(mood_levels[3:6]) / min(3, len(mood_levels[3:]))
        
        if recent_avg > older_avg + 0.5:
            trend = 'improving'
        elif recent_avg < older_avg - 0.5:
            trend = 'declining'
        else:
            trend = 'stable'
    else:
        trend = 'insufficient_data'
    
    # Identify patterns
    if len(mood_levels) >= 3:
        if all(level <= 2 for level in mood_levels[:3]):
            pattern = 'consistently_low'
        elif all(level >= 4 for level in mood_levels[:3]):
            pattern = 'consistently_high'
        elif mood_levels[0] < mood_levels[1] < mood_levels[2]:
            pattern = 'improving'
        elif mood_levels[0] > mood_levels[1] > mood_levels[2]:
            pattern = 'declining'
        else:
            pattern = 'fluctuating'
    else:
        pattern = 'insufficient_data'
    
    return {
        'pattern': pattern,
        'trend': trend,
        'recent_moods': mood_levels[:5],
        'average': round(sum(mood_levels) / len(mood_levels), 2)
    }


def _log_crisis_detection(session_id: str, message: str, risk_level: str, risk_score: float, keywords: List[str]) -> None:
    """Log crisis detection for monitoring"""
    try:
        db.session.execute(
            text("""
                INSERT INTO crisis_detections (session_id, message, risk_level, risk_score, keywords, timestamp)
                VALUES (:session_id, :message, :risk_level, :risk_score, :keywords, :timestamp)
            """),
            {
                'session_id': session_id,
                'message': message,
                'risk_level': risk_level,
                'risk_score': risk_score,
                'keywords': ','.join(keywords),
                'timestamp': datetime.utcnow()
            }
        )
        db.session.commit()
    except Exception as e:
        # Use current_app for logging in request context
        from flask import current_app
        current_app.logger.error(f"Failed to log crisis detection: {e}")
        db.session.rollback()


def _register_additional_routes(app: Flask) -> None:
    """Register additional API routes"""
    
    @app.route("/api/get_or_create_session", methods=['GET'])
    def get_or_create_session_endpoint():
        """Get or create user session"""
        session_id = _get_or_create_session()
        return jsonify({'session_id': session_id})

    @app.route('/api/chat_history', methods=['GET'])
    def get_chat_history():
        """Get chat history for the current session"""
        try:
            session_id = request.headers.get('X-Session-ID')
            if not session_id:
                return jsonify({'error': 'Session ID required'}), 400

            # Get chat messages from database
            messages = db.session.execute(
                text("""
                    SELECT content, is_user, timestamp 
                    FROM chat_messages 
                    WHERE session_id = :session_id 
                    ORDER BY timestamp ASC 
                    LIMIT 50
                """),
                {'session_id': session_id}
            ).fetchall()

            chat_history = []
            for message in messages:
                chat_history.append({
                    'content': message.content,
                    'is_user': message.is_user,
                    'timestamp': message.timestamp.isoformat() if message.timestamp else None
                })

            return jsonify(chat_history)

        except Exception as e:
            app.logger.error(f"Error getting chat history: {e}")
            return jsonify({'error': 'Failed to get chat history'}), 500

    @app.route('/api/mood_history', methods=['GET'])
    @app.limiter.limit("30 per minute")
    def get_mood_history():
        """Get mood history for the current session"""
        try:
            session_id = request.headers.get('X-Session-ID')
            if not session_id:
                return jsonify({'error': 'Session ID required'}), 400

            # Get mood entries from database
            entries = db.session.execute(
                text("""
                    SELECT mood_level, note, timestamp 
                    FROM mood_entries 
                    WHERE session_id = :session_id 
                    ORDER BY timestamp DESC 
                    LIMIT 50
                """),
                {'session_id': session_id}
            ).fetchall()

            mood_history = []
            for entry in entries:
                mood_history.append({
                    'mood_level': entry.mood_level,
                    'note': entry.note,
                    'timestamp': entry.timestamp.isoformat() if entry.timestamp else None
                })

            return jsonify(mood_history)

        except Exception as e:
            app.logger.error(f"Error getting mood history: {e}")
            return jsonify({'error': 'Failed to get mood history'}), 500

    @app.route('/api/mood_entry', methods=['POST'])
    @app.limiter.limit("30 per minute")
    def add_mood_entry():
        """Add a new mood entry"""
        try:
            session_id = request.headers.get('X-Session-ID')
            if not session_id:
                return jsonify({'error': 'Session ID required'}), 400

            data = request.get_json()
            if not data:
                return jsonify({'error': 'No data provided'}), 400

            mood_level = data.get('mood_level')
            note = data.get('note', '')
            timestamp = data.get('timestamp')

            if not mood_level or not isinstance(mood_level, int) or mood_level < 1 or mood_level > 5:
                return jsonify({'error': 'Invalid mood level (1-5 required)'}), 400

            # Parse timestamp if provided, otherwise use current time
            if timestamp:
                try:
                    entry_timestamp = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                except ValueError:
                    entry_timestamp = datetime.utcnow()
            else:
                entry_timestamp = datetime.utcnow()

            # Insert mood entry into database
            db.session.execute(
                text("""
                    INSERT INTO mood_entries (session_id, mood_level, note, timestamp)
                    VALUES (:session_id, :mood_level, :note, :timestamp)
                """),
                {
                    'session_id': session_id,
                    'mood_level': mood_level,
                    'note': note,
                    'timestamp': entry_timestamp
                }
            )
            db.session.commit()

            return jsonify({
                'message': 'Mood entry added successfully',
                'mood_level': mood_level,
                'note': note,
                'timestamp': entry_timestamp.isoformat()
            })

        except Exception as e:
            app.logger.error(f"Error adding mood entry: {e}")
            db.session.rollback()
            return jsonify({'error': 'Failed to add mood entry'}), 500

    @app.route('/api/crisis_detection', methods=['POST'])
    @app.limiter.limit("10 per minute")
    def crisis_detection():
        """Enhanced crisis detection with immediate response"""
        try:
            data = request.get_json()
            if not data:
                return jsonify({'error': 'No data provided'}), 400

            message = data.get('message', '')
            session_id = request.headers.get('X-Session-ID')
            
            if not message:
                return jsonify({'error': 'Message required'}), 400

            # Enhanced crisis detection
            risk_level, risk_score, keywords = _enhanced_crisis_detection(message)
            
            # Immediate response based on risk level
            response = _get_crisis_response(risk_level, risk_score)
            
            # Log crisis detection
            _log_crisis_detection(session_id, message, risk_level, risk_score, keywords)
            
            return jsonify({
                'risk_level': risk_level,
                'risk_score': risk_score,
                'keywords': keywords,
                'response': response,
                'immediate_action_required': risk_level in ['high', 'crisis'],
                'resources': _get_crisis_resources(risk_level)
            })

        except Exception as e:
            app.logger.error(f"Crisis detection error: {e}")
            return jsonify({'error': 'Failed to process crisis detection'}), 500

    @app.route('/api/mood_analytics', methods=['GET'])
    @app.limiter.limit("30 per minute")
    def mood_analytics():
        """Get mood analytics and trends"""
        try:
            session_id = request.headers.get('X-Session-ID')
            if not session_id:
                return jsonify({'error': 'Session ID required'}), 400

            # Get mood entries from database
            entries = db.session.execute(
                text("""
                    SELECT mood_level, note, timestamp 
                    FROM mood_entries 
                    WHERE session_id = :session_id 
                    ORDER BY timestamp DESC 
                    LIMIT 100
                """),
                {'session_id': session_id}
            ).fetchall()

            if not entries:
                return jsonify({
                    'message': 'No mood data available',
                    'analytics': {
                        'average_mood': 0,
                        'mood_trend': 'stable',
                        'total_entries': 0,
                        'weekly_average': 0,
                        'mood_distribution': {}
                    }
                })

            # Calculate analytics
            mood_levels = [entry.mood_level for entry in entries]
            average_mood = sum(mood_levels) / len(mood_levels)
            
            # Mood trend calculation
            recent_moods = mood_levels[:7] if len(mood_levels) >= 7 else mood_levels
            older_moods = mood_levels[7:14] if len(mood_levels) >= 14 else []
            
            if older_moods:
                recent_avg = sum(recent_moods) / len(recent_moods)
                older_avg = sum(older_moods) / len(older_moods)
                if recent_avg > older_avg + 0.5:
                    trend = 'improving'
                elif recent_avg < older_avg - 0.5:
                    trend = 'declining'
                else:
                    trend = 'stable'
            else:
                trend = 'stable'

            # Mood distribution
            mood_distribution = {}
            for level in range(1, 6):
                count = mood_levels.count(level)
                mood_distribution[f"level_{level}"] = count

            # Weekly average
            week_ago = datetime.utcnow() - timedelta(days=7)
            weekly_entries = [entry for entry in entries if entry.timestamp >= week_ago]
            weekly_average = sum(entry.mood_level for entry in weekly_entries) / len(weekly_entries) if weekly_entries else 0

            return jsonify({
                'analytics': {
                    'average_mood': round(average_mood, 2),
                    'mood_trend': trend,
                    'total_entries': len(entries),
                    'weekly_average': round(weekly_average, 2),
                    'mood_distribution': mood_distribution,
                    'recent_entries': len(recent_moods)
                }
            })

        except Exception as e:
            app.logger.error(f"Mood analytics error: {e}")
            return jsonify({'error': 'Failed to get mood analytics'}), 500

    @app.route('/api/wellness_recommendations', methods=['GET'])
    @app.limiter.limit("30 per minute")
    def wellness_recommendations():
        """Get personalized wellness recommendations"""
        try:
            session_id = request.headers.get('X-Session-ID')
            if not session_id:
                return jsonify({'error': 'Session ID required'}), 400

            # Get recent mood data
            recent_entries = db.session.execute(
                text("""
                    SELECT mood_level, note, timestamp 
                    FROM mood_entries 
                    WHERE session_id = :session_id 
                    ORDER BY timestamp DESC 
                    LIMIT 10
                """),
                {'session_id': session_id}
            ).fetchall()

            if not recent_entries:
                return jsonify({
                    'recommendations': _get_default_recommendations(),
                    'message': 'No recent mood data available'
                })

            # Calculate average mood
            avg_mood = sum(entry.mood_level for entry in recent_entries) / len(recent_entries)
            
            # Get personalized recommendations
            recommendations = _get_personalized_recommendations(avg_mood, recent_entries)
            
            return jsonify({
                'recommendations': recommendations,
                'current_mood_average': round(avg_mood, 2),
                'analysis': _analyze_mood_pattern(recent_entries)
            })

        except Exception as e:
            app.logger.error(f"Wellness recommendations error: {e}")
            return jsonify({'error': 'Failed to get recommendations'}), 500

    @app.route('/api/metrics', methods=['GET'])
    def metrics():
        """Prometheus metrics endpoint"""
        try:
            import psutil
            import time
            
            metrics = []
            
            # System metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            # Application metrics
            current_time = time.time()
            
            # Database connection health
            db_health = _check_database_health()
            redis_health = _check_redis_health()
            
            # Build metrics in Prometheus format
            metrics.append(f"# HELP app_cpu_usage CPU usage percentage")
            metrics.append(f"# TYPE app_cpu_usage gauge")
            metrics.append(f"app_cpu_usage {cpu_percent}")
            
            metrics.append(f"# HELP app_memory_usage Memory usage percentage")
            metrics.append(f"# TYPE app_memory_usage gauge")
            metrics.append(f"app_memory_usage {memory.percent}")
            
            metrics.append(f"# HELP app_disk_usage Disk usage percentage")
            metrics.append(f"# TYPE app_disk_usage gauge")
            metrics.append(f"app_disk_usage {disk.percent}")
            
            metrics.append(f"# HELP app_uptime_seconds Application uptime in seconds")
            metrics.append(f"# TYPE app_uptime_seconds counter")
            metrics.append(f"app_uptime_seconds {current_time}")
            
            metrics.append(f"# HELP app_database_health Database health status")
            metrics.append(f"# TYPE app_database_health gauge")
            metrics.append(f"app_database_health {1 if 'healthy' in db_health else 0}")
            
            metrics.append(f"# HELP app_redis_health Redis health status")
            metrics.append(f"# TYPE app_redis_health gauge")
            metrics.append(f"app_redis_health {1 if 'healthy' in redis_health else 0}")
            
            # Request metrics (if available)
            if hasattr(app, 'request_count'):
                metrics.append(f"# HELP app_requests_total Total number of requests")
                metrics.append(f"# TYPE app_requests_total counter")
                metrics.append(f"app_requests_total {app.request_count}")
            
            return '\n'.join(metrics), 200, {'Content-Type': 'text/plain'}
            
        except Exception as e:
            app.logger.error(f"Metrics collection error: {e}")
            return f"# ERROR: {str(e)}", 500, {'Content-Type': 'text/plain'}

    @app.route('/api/self_assessment', methods=['POST'])
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
