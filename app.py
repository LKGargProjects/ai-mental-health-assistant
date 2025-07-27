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
from providers.perplexity import get_perplexity_response
from providers.openai import get_openai_response
from models import db, UserSession, ConversationLog, CrisisEvent, SelfAssessmentEntry, GamifiedTask, UserTaskCompletion, UserProgressPost, PersonalizedFeedback
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

# Predefined assessment questions
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
    },
    {
        "id": 3,
        "question": "How well do you sleep at night?",
        "type": "multiple_choice",
        "options": ["Very well", "Well", "Fairly well", "Poorly", "Very poorly"],
        "category": "sleep"
    },
    {
        "id": 4,
        "question": "How often do you feel anxious or worried?",
        "type": "multiple_choice",
        "options": ["Never", "Rarely", "Sometimes", "Often", "Always"],
        "category": "anxiety"
    },
    {
        "id": 5,
        "question": "How connected do you feel to others?",
        "type": "scale",
        "min": 1,
        "max": 10,
        "category": "social"
    },
    {
        "id": 6,
        "question": "How often do you engage in activities you enjoy?",
        "type": "multiple_choice",
        "options": ["Daily", "Several times a week", "Once a week", "Rarely", "Never"],
        "category": "enjoyment"
    },
    {
        "id": 7,
        "question": "How would you describe your energy levels?",
        "type": "multiple_choice",
        "options": ["Very high", "High", "Moderate", "Low", "Very low"],
        "category": "energy"
    },
    {
        "id": 8,
        "question": "How often do you practice self-care activities?",
        "type": "multiple_choice",
        "options": ["Daily", "Several times a week", "Once a week", "Rarely", "Never"],
        "category": "self_care"
    }
]

# Predefined gamified tasks
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
    },
    {
        "name": "Stress Relief Walk",
        "description": "Take a 10-minute walk outside",
        "points": 20,
        "task_type": "stress_management",
        "is_recurring": True
    },
    {
        "name": "Digital Detox",
        "description": "Spend 30 minutes without checking your phone",
        "points": 25,
        "task_type": "stress_management",
        "is_recurring": False
    },
    {
        "name": "Positive Affirmation",
        "description": "Repeat a positive affirmation 3 times",
        "points": 10,
        "task_type": "mindfulness",
        "is_recurring": True
    }
]

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
        elif PROVIDER == 'perplexity' and PPLX_API_KEY:
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

# New endpoints for enhanced features

@app.route("/assessments/start", methods=["GET"])
def start_assessment():
    """Get assessment questions"""
    try:
        return jsonify({
            "questions": ASSESSMENT_QUESTIONS,
            "total_questions": len(ASSESSMENT_QUESTIONS)
        })
    except Exception as e:
        app.logger.error(f"Error in /assessments/start: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/assessments/submit", methods=["POST"])
@limiter.limit("5 per hour")
def submit_assessment():
    """Submit assessment responses and get AI feedback"""
    try:
        data = request.get_json()
        if not data or 'responses' not in data:
            return jsonify({"error": "No responses provided"}), 400

        session_id = get_or_create_session()
        responses = data['responses']
        
        # Calculate basic score (simple implementation)
        total_score = 0
        max_score = len(ASSESSMENT_QUESTIONS) * 5  # Assuming 5-point scale max
        
        for response in responses:
            if response.get('type') == 'multiple_choice':
                # Map options to scores (1-5)
                options = response.get('options', [])
                selected = response.get('answer', '')
                if selected in options:
                    score = options.index(selected) + 1
                    total_score += score
            elif response.get('type') == 'scale':
                score = int(response.get('answer', 5))
                total_score += score
        
        # Normalize score to 0-100
        normalized_score = (total_score / max_score) * 100 if max_score > 0 else 0
        
        # Create assessment entry
        assessment_entry = SelfAssessmentEntry(
            user_session_id=session_id,
            questions_and_answers=responses,
            raw_score=normalized_score,
            summary_data={
                'total_questions': len(ASSESSMENT_QUESTIONS),
                'completed_questions': len(responses),
                'score_percentage': normalized_score
            }
        )
        db.session.add(assessment_entry)
        
        # Generate AI feedback
        feedback_prompt = f"""
        Based on the following mental health assessment responses, provide personalized, empathetic, and actionable feedback:
        
        Assessment Score: {normalized_score:.1f}%
        Responses: {responses}
        
        Please provide:
        1. A brief interpretation of their current mental health state
        2. 2-3 specific, actionable recommendations
        3. Encouraging words of support
        4. Suggestions for when to seek professional help
        
        Keep the response warm, supportive, and under 300 words.
        """
        
        # Get AI feedback
        if PROVIDER == 'openai' and OPENAI_API_KEY:
            ai_feedback = get_openai_response(feedback_prompt, 'mental_health')
        elif PROVIDER == 'gemini' and GEMINI_API_KEY:
            ai_feedback = get_gemini_response(feedback_prompt, 'mental_health', session_id)
        elif PROVIDER == 'perplexity' and PPLX_API_KEY:
            ai_feedback = get_perplexity_response(feedback_prompt, 'mental_health')
        else:
            ai_feedback = "Thank you for completing the assessment. Your responses help us understand your current mental health state. Consider reaching out to a mental health professional if you're experiencing persistent difficulties."
        
        assessment_entry.ai_feedback = ai_feedback
        
        # Create personalized feedback record
        feedback_record = PersonalizedFeedback(
            user_session_id=session_id,
            assessment_id=assessment_entry.id,
            feedback_content=ai_feedback,
            feedback_type='assessment',
            ai_provider=PROVIDER
        )
        db.session.add(feedback_record)
        
        db.session.commit()
        
        return jsonify({
            "assessment_id": assessment_entry.id,
            "score": normalized_score,
            "feedback": ai_feedback,
            "timestamp": assessment_entry.timestamp.isoformat()
        })
        
    except Exception as e:
        app.logger.error(f"Error in /assessments/submit: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/tasks", methods=["GET"])
def get_tasks():
    """Get available gamified tasks"""
    try:
        # Ensure default tasks exist
        existing_tasks = GamifiedTask.query.filter_by(is_active=True).all()
        if not existing_tasks:
            # Create default tasks
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
        app.logger.error(f"Error in /tasks: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/tasks/<int:task_id>/complete", methods=["POST"])
@limiter.limit("20 per hour")
def complete_task(task_id):
    """Mark a task as completed"""
    try:
        session_id = get_or_create_session()
        
        task = GamifiedTask.query.get(task_id)
        if not task:
            return jsonify({"error": "Task not found"}), 404
        
        # Check if already completed today (for recurring tasks)
        today = datetime.utcnow().date()
        existing_completion = UserTaskCompletion.query.filter(
            UserTaskCompletion.user_session_id == session_id,
            UserTaskCompletion.task_id == task_id,
            db.func.date(UserTaskCompletion.completion_timestamp) == today
        ).first()
        
        if existing_completion:
            return jsonify({"error": "Task already completed today"}), 400
        
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
        app.logger.error(f"Error in /tasks/{task_id}/complete: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/reminders", methods=["GET"])
def get_reminders():
    """Get overdue or upcoming tasks for user"""
    try:
        session_id = get_or_create_session()
        
        # Get user's completed tasks today
        today = datetime.utcnow().date()
        completed_today = UserTaskCompletion.query.filter(
            UserTaskCompletion.user_session_id == session_id,
            db.func.date(UserTaskCompletion.completion_timestamp) == today
        ).all()
        completed_task_ids = [comp.task_id for comp in completed_today]
        
        # Get available tasks that haven't been completed today
        available_tasks = GamifiedTask.query.filter(
            GamifiedTask.is_active == True,
            ~GamifiedTask.id.in_(completed_task_ids)
        ).all()
        
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
        app.logger.error(f"Error in /reminders: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/progress/share", methods=["POST"])
@limiter.limit("10 per hour")
def share_progress():
    """Share user progress with community"""
    try:
        data = request.get_json()
        session_id = get_or_create_session()
        
        # Get user's recent progress data
        recent_assessments = SelfAssessmentEntry.query.filter_by(
            user_session_id=session_id
        ).order_by(SelfAssessmentEntry.timestamp.desc()).limit(3).all()
        
        recent_tasks = UserTaskCompletion.query.filter_by(
            user_session_id=session_id
        ).order_by(UserTaskCompletion.completion_timestamp.desc()).limit(5).all()
        
        # Create anonymized progress summary
        progress_summary = {
            "assessment_count": len(recent_assessments),
            "task_completions": len(recent_tasks),
            "total_points_earned": sum(task.earned_points for task in recent_tasks),
            "last_assessment_score": recent_assessments[0].raw_score if recent_assessments else None
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
        app.logger.error(f"Error in /progress/share: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/community/feed", methods=["GET"])
def get_community_feed():
    """Get public progress posts from community"""
    try:
        # Get recent public progress posts
        public_posts = UserProgressPost.query.filter_by(
            privacy_setting='public'
        ).order_by(UserProgressPost.timestamp.desc()).limit(20).all()
        
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
        app.logger.error(f"Error in /community/feed: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/assessments/history", methods=["GET"])
def get_assessment_history():
    """Get user's assessment history"""
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
                "summary": assessment.summary_data,
                "feedback": assessment.ai_feedback
            })
        
        return jsonify({"history": history})
        
    except Exception as e:
        app.logger.error(f"Error in /assessments/history: {e}", exc_info=True)
        return jsonify({"error": f"Error: {str(e)}"}), 500

@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "status": "ok", 
        "message": "AI Mental Health API is running",
        "provider": PROVIDER,
        "has_gemini_key": bool(GEMINI_API_KEY),
        "has_openai_key": bool(OPENAI_API_KEY),
        "has_perplexity_key": bool(PPLX_API_KEY)
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
        "crisis_events": CrisisEvent.query.count(),
        "total_assessments": SelfAssessmentEntry.query.count(),
        "total_task_completions": UserTaskCompletion.query.count(),
        "total_progress_posts": UserProgressPost.query.count()
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
