from flask import Flask, request, jsonify, session, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_session import Session
from dotenv import load_dotenv
import os
import redis
from datetime import datetime
import uuid

# Load environment variables
load_dotenv()

from providers.gemini import get_gemini_response
from providers.openai import get_openai_response

# Try to import perplexity, but don't fail if it's not available
try:
    from providers.perplexity import get_perplexity_response
    PERPLEXITY_AVAILABLE = True
except ImportError:
    PERPLEXITY_AVAILABLE = False
    print("⚠️ Perplexity provider not available")

from models import db, UserSession, ConversationLog, CrisisEvent
from crisis_detection import detect_crisis_level
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_cors import CORS

app = Flask(__name__)
CORS(app, supports_credentials=True)

# Enhanced configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-key-change-in-prod')

# Database configuration with fallback
database_url = os.environ.get('DATABASE_URL')
if database_url and database_url != 'port':
    # Convert postgresql:// to postgresql+psycopg:// for psycopg3
    if database_url.startswith('postgresql://'):
        database_url = database_url.replace('postgresql://', 'postgresql+psycopg://')
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
else:
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mental_health.db'

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Environment-based session configuration
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'local')

# Try Redis first, fallback to filesystem
redis_url = os.environ.get('REDIS_URL')
if redis_url and redis_url != 'port':
    try:
        # Test Redis connection
        redis_client = redis.from_url(redis_url)
        redis_client.ping()  # Test connection
        app.config['SESSION_TYPE'] = 'redis'
        app.config['SESSION_REDIS'] = redis_client
        app.logger.info("✅ Redis sessions enabled")
    except Exception as e:
        app.logger.warning(f"⚠️ Redis connection failed: {e}, using filesystem sessions")
        app.config['SESSION_TYPE'] = 'filesystem'
        app.config['SESSION_REDIS'] = None
else:
    app.logger.info("ℹ️ No REDIS_URL found, using filesystem sessions")
    app.config['SESSION_TYPE'] = 'filesystem'
    app.config['SESSION_REDIS'] = None

app.config['SESSION_PERMANENT'] = False
app.config['SESSION_USE_SIGNER'] = False  # Disable signing for now

# Initialize extensions
db.init_app(app)
Session(app)

# Rate limiting with Redis backend
limiter = Limiter(
    key_func=get_remote_address,
    app=app,
    default_limits=["100 per day", "20 per hour"],
    storage_uri=os.environ.get('REDIS_URL', 'memory://')
)

# Get API keys from environment
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
PPLX_API_KEY = os.getenv("PPLX_API_KEY")
PROVIDER = os.getenv('AI_PROVIDER', 'gemini')

def get_or_create_session():
    """Get or create anonymous user session"""
    # Try to get existing session from Flask session
    session_id = session.get('session_id')
    
    if not session_id:
        # Create new session
        session_id = str(uuid.uuid4())
        session['session_id'] = session_id
        
        # Create new user session in database
        try:
            user_session = UserSession(id=session_id)
            db.session.add(user_session)
            db.session.commit()
            app.logger.info(f"✅ Created new session: {session_id}")
        except Exception as e:
            db.session.rollback()
            app.logger.warning(f"⚠️ Session {session_id} might already exist: {e}")
    else:
        app.logger.info(f"ℹ️ Using existing session: {session_id}")
    
    return session_id

@app.before_request
def ensure_session_id_is_str():
    """Ensure session_id is always a string"""
    session_id = session.get('session_id')
    if isinstance(session_id, bytes):
        session['session_id'] = session_id.decode('utf-8')
        app.logger.info("🔄 Converted bytes session_id to string")

@app.route("/chat", methods=["POST"])
@limiter.limit("10 per minute")
def chat():
    try:
        data = request.get_json()
        if not data or 'message' not in data:
            return jsonify({"error": "No message provided"}), 400

        message = data['message']
        mode = data.get('mode', 'mental_health')
        
        # Get or create anonymous session
        session_id = get_or_create_session()
        
        # Analyze message for crisis indicators
        risk_level, resources = detect_crisis_level(message)
        
        # Get AI response based on provider
        if PROVIDER == 'openai' and OPENAI_API_KEY:
            response = get_openai_response(message, mode)
        elif PROVIDER == 'gemini' and GEMINI_API_KEY:
            response = get_gemini_response(message, mode, session_id)
        elif PROVIDER == 'perplexity' and PPLX_API_KEY and PERPLEXITY_AVAILABLE:
            response = get_perplexity_response(message, mode)
        else:
            response = "I understand you're sharing something personal. I'm here to listen and support you. Would you like to tell me more about how you're feeling?"

        # Log conversation
        conversation_log = ConversationLog(
            session_id=session_id,
            provider=PROVIDER,
            risk_score=risk_level
        )
        db.session.add(conversation_log)
        
        # Handle crisis situations
        response_data = {
            "response": response,
            "risk_level": risk_level,
            "resources": resources,
            "timestamp": datetime.utcnow().isoformat(),
            "provider": PROVIDER
        }
        
        if risk_level in ['high', 'medium']:
            # Log crisis event
            crisis_event = CrisisEvent(
                session_id=session_id,
                risk_level=risk_level,
                intervention_taken="AI response with resources",
                escalated=risk_level == 'high'
            )
            db.session.add(crisis_event)
        
        # Update session activity
        user_session = UserSession.query.get(session_id)
        if user_session:
            user_session.last_active = datetime.utcnow()
            user_session.conversation_count += 1
            user_session.risk_level = risk_level
        
        db.session.commit()
        
        app.logger.info(f"Session: {session_id}, Provider: {PROVIDER}, Risk: {risk_level}")
        return jsonify(response_data)
        
    except Exception as e:
        app.logger.error(f"Error in /chat: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "status": "ok", 
        "message": "AI Mental Health API is running",
        "provider": PROVIDER,
        "has_gemini_key": bool(GEMINI_API_KEY),
        "has_openai_key": bool(OPENAI_API_KEY),
        "has_perplexity_key": bool(PPLX_API_KEY and PERPLEXITY_AVAILABLE)
    })

@app.route("/ping", methods=["GET"])
def ping():
    return "pong", 200

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow()})

@app.route("/stats", methods=["GET"])
def stats():
    return jsonify({
        "total_sessions": UserSession.query.count(),
        "total_conversations": ConversationLog.query.count(),
        "crisis_events": CrisisEvent.query.count()
    })

@app.route('/get_or_create_session', methods=['GET'])
def get_or_create_session_endpoint():
    session_id = get_or_create_session()
    return jsonify({"session_id": session_id})

@app.route('/chat_history', methods=['GET'])
def get_chat_history():
    session_id = session.get('session_id')
    if not session_id:
        return jsonify([])
    
    conversations = ConversationLog.query.filter_by(session_id=session_id).all()
    return jsonify([{
        'id': conv.id,
        'provider': conv.provider,
        'risk_score': conv.risk_score,
        'timestamp': conv.timestamp.isoformat() if conv.timestamp else None
    } for conv in conversations])

@app.route('/mood_history', methods=['GET'])
def get_mood_history():
    # For now, return empty list as we haven't implemented mood persistence
    return jsonify([])

@app.route('/mood_entry', methods=['POST'])
def add_mood_entry():
    try:
        data = request.get_json()
        # For now, just echo back the entry as we haven't implemented persistence
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 400

with app.app_context():
    db.create_all()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    app.run(host="0.0.0.0", port=port, debug=False)
