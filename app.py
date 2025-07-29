from flask import Flask, request, jsonify, session, render_template, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_session import Session
from dotenv import load_dotenv
import os
import redis
import json
from datetime import datetime
import uuid

# Load environment variables
load_dotenv()

from providers.gemini import get_gemini_response
from providers.perplexity import get_perplexity_response
from providers.openai import get_openai_response
from models import db, UserSession, Message, ConversationLog, CrisisEvent, SelfAssessmentEntry
from crisis_detection import detect_crisis_level
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_cors import CORS

app = Flask(__name__, static_folder='ai_buddy_web/build/web', static_url_path='')

# Enhanced CORS configuration for Flutter web
CORS(app, 
     origins=[
         "http://localhost:8080", 
         "http://127.0.0.1:8080", 
         "http://localhost:3000",
         "http://localhost:9100",
         "http://127.0.0.1:9100"
     ],
     supports_credentials=True,
     allow_headers=["Content-Type", "Authorization", "X-Session-ID", "Accept"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     expose_headers=["Content-Type", "X-Session-ID"])

# Enhanced configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-key-change-in-prod')

# Database configuration with fallback
database_url = os.environ.get('DATABASE_URL')
print(f"DEBUG: DATABASE_URL from env: {database_url}")
if database_url and database_url.strip() and database_url != 'port':
    # Convert postgresql:// to postgresql+psycopg:// for psycopg3
    if database_url.startswith('postgresql://'):
        database_url = database_url.replace('postgresql://', 'postgresql+psycopg://')
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
    print(f"Using PostgreSQL: {database_url}")
else:
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mental_health.db'
    print("Using SQLite fallback")

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Environment-based session configuration
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'local')

# Try Redis first, fallback to filesystem
redis_url = os.environ.get('REDIS_URL')
if redis_url and redis_url != 'port' and redis_url.strip():
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
    app.logger.info("ℹ️ No REDIS_URL found or invalid, using filesystem sessions")
    app.config['SESSION_TYPE'] = 'filesystem'
    app.config['SESSION_REDIS'] = None

app.config['SESSION_PERMANENT'] = False
app.config['SESSION_USE_SIGNER'] = False  # Disable signing for now

# Initialize extensions
try:
    db.init_app(app)
    Session(app)
    app.logger.info("✅ Database and session extensions initialized")
except Exception as e:
    app.logger.error(f"❌ Failed to initialize database extensions: {e}")
    # Continue without database if needed

# Rate limiting with Redis backend
try:
    limiter = Limiter(
        key_func=get_remote_address,
        app=app,
        default_limits=["500 per day", "100 per hour"],
        storage_uri=os.environ.get('REDIS_URL', 'memory://')
    )
    app.logger.info("✅ Rate limiter initialized")
except Exception as e:
    app.logger.error(f"❌ Failed to initialize rate limiter: {e}")
    # Create a simple limiter without Redis
    limiter = Limiter(
        key_func=get_remote_address,
        app=app,
        default_limits=["500 per day", "100 per hour"],
        storage_uri='memory://'
    )

# Get API keys from environment
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
PPLX_API_KEY = os.getenv("PPLX_API_KEY")
PROVIDER = os.getenv('AI_PROVIDER', 'gemini')

def get_or_create_session():
    """Get or create anonymous user session"""
    # First check if session ID is provided in header (from frontend)
    header_session_id = request.headers.get('X-Session-ID')
    if header_session_id:
        # Use the session ID from frontend
        session_id = header_session_id
        # Store it in Flask session for consistency
        session['session_id'] = session_id
        app.logger.info(f"ℹ️ Using session from header: {session_id}")
    else:
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

@app.route("/api/chat", methods=["POST"])
@limiter.limit("30 per minute")
def chat():
    print("🔥🔥🔥 NEW VERSION OF CHAT FUNCTION IS RUNNING! 🔥🔥🔥")
    try:
        data = request.get_json()
        if not data or 'message' not in data:
            return jsonify({"error": "No message provided"}), 400

        message = data['message']
        mode = data.get('mode', 'mental_health')
        
        # Get or create anonymous session
        session_id = get_or_create_session()
        
        # Analyze message for crisis indicators
        risk_score, resources = detect_crisis_level(message)
        
        # Convert numeric risk score to string risk level for response
        if risk_score >= 0.8:
            risk_level = 'high'
        elif risk_score >= 0.5:
            risk_level = 'medium'
        elif risk_score >= 0.2:
            risk_level = 'low'
        else:
            risk_level = 'none'
        
        # Get AI response based on provider
        if PROVIDER == 'openai' and OPENAI_API_KEY:
            response = get_openai_response(message, mode)
        elif PROVIDER == 'gemini' and GEMINI_API_KEY:
            response = get_gemini_response(message, mode, session_id)
        elif PROVIDER == 'perplexity' and PPLX_API_KEY:
            response = get_perplexity_response(message, mode)
        else:
            response = "I understand you're sharing something personal. I'm here to listen and support you. Would you like to tell me more about how you're feeling?"

        # Store user message
        user_message = Message(
            session_id=session_id,
            content=message,
            is_user=True,
            risk_level=risk_level
        )
        db.session.add(user_message)
        
        # Store AI response
        ai_message = Message(
            session_id=session_id,
            content=response,
            is_user=False,
            risk_level=risk_level,
            resources=json.dumps(resources) if resources else None
        )
        db.session.add(ai_message)
        
        # Log conversation metadata
        print("DEBUG: risk_score to be inserted:", risk_score, type(risk_score))
        # Ensure risk_score is float
        if not isinstance(risk_score, float):
            try:
                risk_score = float(risk_score)
            except (ValueError, TypeError):
                risk_score = 0.0
        conversation_log = ConversationLog(
            session_id=session_id,
            provider=PROVIDER,
            risk_score=risk_score
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
        app.logger.error(f"Error in /api/chat: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/", methods=["GET"])
def index():
    app.logger.info(f"Root route called. Static folder: {app.static_folder}")
    app.logger.info(f"Static folder exists: {os.path.exists(app.static_folder)}")
    app.logger.info(f"Index.html exists: {os.path.exists(os.path.join(app.static_folder, 'index.html'))}")
    
    # Try to serve the Flutter web app
    if os.path.exists(app.static_folder) and os.path.exists(os.path.join(app.static_folder, 'index.html')):
        return send_from_directory(app.static_folder, 'index.html')
    else:
        # Fallback: return a simple HTML page with links to the API
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>AI Mental Health Assistant</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .container { max-width: 600px; margin: 0 auto; }
                .api-link { display: block; margin: 10px 0; padding: 10px; background: #f0f0f0; text-decoration: none; color: #333; }
                .api-link:hover { background: #e0e0e0; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>AI Mental Health Assistant</h1>
                <p>The Flutter web app is not available. Here are the API endpoints:</p>
                <a href="/api/health" class="api-link">Health Check</a>
                <a href="/api/deploy-test" class="api-link">Deploy Test</a>
                <a href="/api/stats" class="api-link">Statistics</a>
                <p>Static folder: {}</p>
                <p>Static folder exists: {}</p>
                <p>Index.html exists: {}</p>
            </div>
        </body>
        </html>
        """.format(app.static_folder, os.path.exists(app.static_folder), os.path.exists(os.path.join(app.static_folder, 'index.html')))

@app.route("/test", methods=["GET"])
def test():
    return "Test route working!"

@app.route("/simple", methods=["GET"])
def simple():
    return "Simple route working!"

@app.route("/api/ping", methods=["GET"])
def ping():
    return "pong", 200

@app.route("/api/health", methods=["GET"])
def health():
    try:
        # Test basic functionality
        health_status = {
            "status": "healthy", 
            "timestamp": datetime.utcnow().isoformat(),
            "environment": ENVIRONMENT,
            "provider": PROVIDER,
            "has_gemini_key": bool(GEMINI_API_KEY),
            "has_openai_key": bool(OPENAI_API_KEY),
            "has_perplexity_key": bool(PPLX_API_KEY),
            "redis_url_set": bool(os.environ.get('REDIS_URL')),
            "port": os.environ.get('PORT', '5055'),
            "cors_enabled": True,
            "endpoints": [
                "/api/health",
                "/api/chat", 
                "/api/get_or_create_session",
                "/api/self_assessment",
                "/api/mood_history",
                "/api/mood_entry"
            ],
            "cors_origins": [
                "http://localhost:8080", 
                "http://127.0.0.1:8080", 
                "http://localhost:3000",
                "http://localhost:9100",
                "http://127.0.0.1:9100"
            ]
        }
        return jsonify(health_status)
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 500

@app.route("/api/deploy-test", methods=["GET"])
def deploy_test():
    """Simple endpoint to test if deployment is working"""
    return jsonify({
        "message": "Deployment test successful",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": ENVIRONMENT
    })

@app.route("/api/stats", methods=["GET"])
def stats():
    return jsonify({
        "total_sessions": UserSession.query.count(),
        "total_conversations": ConversationLog.query.count(),
        "crisis_events": CrisisEvent.query.count()
    })

@app.route('/api/get_or_create_session', methods=['GET'])
def get_or_create_session_endpoint():
    session_id = get_or_create_session()
    return jsonify({"session_id": session_id})

@app.route('/api/chat_history', methods=['GET'])
def get_chat_history():
    # Use the same session logic as chat endpoint
    session_id = get_or_create_session()
    if not session_id:
        return jsonify([])
    
    messages = Message.query.filter_by(session_id=session_id).order_by(Message.timestamp).all()
    return jsonify([{
        'id': msg.id,
        'content': msg.content,
        'isUser': msg.is_user,
        'timestamp': msg.timestamp.isoformat() if msg.timestamp else None,
        'riskLevel': msg.risk_level,
        'resources': json.loads(msg.resources) if msg.resources else None
    } for msg in messages])

@app.route('/api/mood_history', methods=['GET'])
def get_mood_history():
    # Use the same session logic as other endpoints
    session_id = get_or_create_session()
    if not session_id:
        return jsonify([])
    
    # For now, return empty list as we haven't implemented mood persistence
    return jsonify([])

@app.route('/api/mood_entry', methods=['POST'])
def add_mood_entry():
    try:
        # Use the same session logic as other endpoints
        session_id = get_or_create_session()
        if not session_id:
            return jsonify({"error": "No session available"}), 400
            
        data = request.get_json()
        # For now, just echo back the entry as we haven't implemented persistence
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 400

@app.route('/api/self_assessment', methods=['POST'])
def submit_self_assessment():
    try:
        # Parse incoming JSON data
        data = request.get_json()
        if not data or not isinstance(data, dict):
            return jsonify({'error': 'Invalid or missing JSON data'}), 400

        # Retrieve session_id from header or session
        session_id = request.headers.get('X-Session-ID') or session.get('session_id')
        if not session_id:
            return jsonify({'error': 'Session ID is required'}), 400

        # For now, just return success without database operations
        return jsonify({'success': True, 'message': 'Assessment received'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

with app.app_context():
    try:
        db.create_all()
        app.logger.info("✅ Database tables created successfully")
    except Exception as e:
        app.logger.error(f"❌ Failed to create database tables: {e}")
        # Continue without database if needed

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5055))
    app.run(host="0.0.0.0", port=port, debug=False)
