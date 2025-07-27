from flask import Flask, request, jsonify, session, render_template
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv
import os
import uuid
from datetime import datetime
from crisis_detection import detect_crisis_level
from providers.openai import get_openai_response
from providers.gemini import get_gemini_response
from providers.perplexity import get_perplexity_response

load_dotenv()

app = Flask(__name__)
CORS(app, supports_credentials=True)  # Enable CORS for all routes

# Configure session
app.secret_key = os.getenv('SECRET_KEY', 'your-secret-key')

# Configure rate limiting
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["100 per minute"],
    storage_uri="memory://",
)

# Providers configuration
PROVIDER = os.getenv('AI_PROVIDER', 'gemini')  # Default to Gemini
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
PERPLEXITY_API_KEY = os.getenv('PPLX_API_KEY')  # Updated to match your env variable name

def get_mock_response(message):
    """Provide a mock response for testing"""
    return "I understand you're sharing something personal. I'm here to listen and support you. Would you like to tell me more about how you're feeling?"

@app.route('/')
def home():
    return jsonify({
        "status": "ok", 
        "message": "AI Mental Health API is running",
        "provider": PROVIDER,
        "has_gemini_key": bool(GEMINI_API_KEY),
        "has_openai_key": bool(OPENAI_API_KEY),
        "has_perplexity_key": bool(PERPLEXITY_API_KEY)
    })

@app.route('/get_or_create_session', methods=['GET'])
def get_or_create_session():
    if 'session_id' not in session:
        session['session_id'] = str(uuid.uuid4())
    return jsonify({"session_id": session['session_id']})

@app.route('/chat', methods=['POST'])
@limiter.limit("20 per minute")
def chat():
    try:
        data = request.get_json()
        if not data or 'message' not in data:
            return jsonify({"error": "No message provided"}), 400

        message = data['message']
        mode = data.get('mode', 'mental_health')  # Default to mental health mode
        session_id = request.headers.get('X-Session-ID')  # Get session ID from header

        print(f"Using provider: {PROVIDER}")  # Debug log
        print(f"Message: {message}")  # Debug log
        print(f"Session ID: {session_id}")  # Debug log

        # Get response based on provider
        if PROVIDER == 'openai' and OPENAI_API_KEY:
            response = get_openai_response(message, mode)
        elif PROVIDER == 'gemini' and GEMINI_API_KEY:
            response = get_gemini_response(message, mode, session_id)  # Pass session_id
        elif PROVIDER == 'perplexity' and PERPLEXITY_API_KEY:
            response = get_perplexity_response(message, mode)
        else:
            # Use mock response if no valid provider is configured
            response = get_mock_response(message)

        # Detect crisis level
        risk_level, resources = detect_crisis_level(message)

        return jsonify({
            "response": response,
            "risk_level": risk_level,
            "resources": resources,
            "timestamp": datetime.utcnow().isoformat(),
            "provider": PROVIDER  # Include provider in response for debugging
        })

    except Exception as e:
        print(f"Error in chat endpoint: {str(e)}")  # Debug log
        return jsonify({
            "error": "An error occurred while processing your request. Please try again."
        }), 500

@app.route('/chat_history', methods=['GET'])
def get_chat_history():
    # For now, return empty list as we haven't implemented persistence
    return jsonify([])

@app.route('/mood_history', methods=['GET'])
def get_mood_history():
    # For now, return empty list as we haven't implemented persistence
    return jsonify([])

@app.route('/mood_entry', methods=['POST'])
def add_mood_entry():
    try:
        data = request.get_json()
        # For now, just echo back the entry as we haven't implemented persistence
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5050))
    debug = os.getenv('FLASK_ENV') == 'development'
    print(f"Starting server with provider: {PROVIDER}")  # Debug log
    print(f"Gemini API key present: {bool(GEMINI_API_KEY)}")  # Debug log
    app.run(host='0.0.0.0', port=port, debug=debug)
