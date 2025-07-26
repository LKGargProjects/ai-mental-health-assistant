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

from providers.gemini import GeminiProvider
from providers.perplexity import PerplexityProvider
from models import db, UserSession, ConversationLog, CrisisEvent
from crisis_detection import CrisisDetector
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
#from flask_cors import CORS

app = Flask(__name__)

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
    storage_uri=os.environ.get('REDIS_URL', 'redis://redis:6379/0')
)

# Initialize crisis detector
crisis_detector = CrisisDetector()

# Get API keys from environment
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PPLX_API_KEY = os.getenv("PPLX_API_KEY")

def get_provider(provider_name):
    if provider_name == "gemini":
        return GeminiProvider(GEMINI_API_KEY)
    elif provider_name == "perplexity":
        return PerplexityProvider(PPLX_API_KEY)
    else:
        raise ValueError(f"Provider '{provider_name}' is not active.")

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
        prompt = data.get("prompt", "")
        history = data.get("history", [])
        provider_name = data.get("provider", "gemini")
        
        # Debug: Check API keys
        app.logger.info(f"GEMINI_API_KEY exists: {bool(GEMINI_API_KEY)}")
        app.logger.info(f"PPLX_API_KEY exists: {bool(PPLX_API_KEY)}")
        
        # Validate prompt length
        if len(prompt) > 1000:
            return jsonify({"error": "Message too long"}), 400

        # Get or create anonymous session
        session_id = get_or_create_session()
        
        # Analyze message for crisis indicators
        crisis_analysis = crisis_detector.analyze_message(prompt)
        
        # Get AI response
        provider = get_provider(provider_name)
        
        # Enhanced prompt for mental health context
        enhanced_prompt = f"""You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies.
        
        User message: {prompt}"""
        
        answer = provider.chat(enhanced_prompt, history)
        
        # Log conversation
        conversation_log = ConversationLog(
            session_id=session_id,
            provider=provider_name,
            risk_score=crisis_analysis['risk_score']
        )
        db.session.add(conversation_log)
        
        # Handle crisis situations
        response_data = {"answer": answer}
        
        if crisis_analysis['risk_level'] in ['critical', 'high']:
            # Log crisis event
            crisis_event = CrisisEvent(
                session_id=session_id,
                risk_level=crisis_analysis['risk_level'],
                intervention_taken=crisis_analysis['intervention'],
                escalated=crisis_analysis['risk_level'] == 'critical'
            )
            db.session.add(crisis_event)
            
            # Add crisis resources to response
            response_data['crisis_resources'] = crisis_analysis['resources']
            response_data['risk_level'] = crisis_analysis['risk_level']
        
        # Update session activity
        user_session = UserSession.query.get(session_id)
        if user_session:
            user_session.last_active = datetime.utcnow()
            user_session.conversation_count += 1
            user_session.risk_level = crisis_analysis['risk_level']
        
        db.session.commit()
        
        app.logger.info(f"Session: {session_id}, Provider: {provider_name}, Risk: {crisis_analysis['risk_level']}")
        # Debug print and force session_id to string
        print("DEBUG session_id type:", type(session.get('session_id')), session.get('session_id'))
        if isinstance(session.get('session_id'), bytes):
            session['session_id'] = session['session_id'].decode('utf-8')
        return jsonify(response_data)
        
    except Exception as e:
        app.logger.error(f"Error in /chat: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")

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

with app.app_context():
    db.create_all()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    app.run(host="0.0.0.0", port=port, debug=False)
