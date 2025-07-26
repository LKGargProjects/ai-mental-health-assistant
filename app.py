from flask import Flask, request, jsonify, session
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

app = Flask(__name__)

# Enhanced configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-key-change-in-prod')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///mental_health.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Environment-based session configuration
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'local')

if ENVIRONMENT == 'docker':
    # Docker environment - use Redis
    app.config['SESSION_TYPE'] = 'redis'
    app.config['SESSION_REDIS'] = redis.from_url(os.environ.get('REDIS_URL', 'redis://redis:6379/0'))
elif ENVIRONMENT == 'render':
    # Render environment - use Redis if available, otherwise filesystem
    redis_url = os.environ.get('REDIS_URL')
    if redis_url and redis_url != 'port':
        app.config['SESSION_TYPE'] = 'redis'
        app.config['SESSION_REDIS'] = redis.from_url(redis_url)
    else:
        app.config['SESSION_TYPE'] = 'filesystem'
elif ENVIRONMENT == 'azure':
    # Azure environment - use Azure Redis Cache and PostgreSQL
    redis_url = os.environ.get('REDIS_URL')
    if redis_url:
        app.config['SESSION_TYPE'] = 'redis'
        app.config['SESSION_REDIS'] = redis.from_url(redis_url)
    else:
        app.config['SESSION_TYPE'] = 'filesystem'
else:
    # Local environment - use filesystem for simplicity
    app.config['SESSION_TYPE'] = 'filesystem'

app.config['SESSION_PERMANENT'] = False
app.config['SESSION_USE_SIGNER'] = True

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
    session_id = session.get('session_id')
    # Ensure session_id is always a string
    if isinstance(session_id, bytes):
        session_id = session_id.decode('utf-8')
    if not session_id:
        session_id = str(uuid.uuid4())
        session['session_id'] = session_id
        # Create new user session in database
        user_session = UserSession(id=session_id)
        db.session.add(user_session)
        db.session.commit()
    else:
        session['session_id'] = str(session_id)
    return session['session_id']

@app.before_request
def ensure_session_id_is_str():
    session_id = session.get('session_id')
    if isinstance(session_id, bytes):
        session['session_id'] = session_id.decode('utf-8')

@app.route("/chat", methods=["POST"])
@limiter.limit("10 per minute")
def chat():
    try:
        data = request.get_json()
        prompt = data.get("prompt", "")
        history = data.get("history", [])
        provider_name = data.get("provider", "gemini")
        
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
        return jsonify({"error": "I'm having trouble responding right now. Please try again."}), 500

@app.route("/ping", methods=["GET"])
def ping():
    return "pong", 200

with app.app_context():
    db.create_all()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    app.run(host="0.0.0.0", port=port, debug=False)
