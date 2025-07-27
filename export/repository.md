# AI Mental Health Assistant - Complete Repository Documentation

## Repository Overview
This document contains the complete source code and documentation for the AI Mental Health Assistant project.

**Repository URL:** https://github.com/LKGargProjects/ai-mental-health-assistant  
**Last Updated:** $(date)  
**Branch:** $(git branch --show-current)

## Table of Contents
1. [Project Structure](#project-structure)
2. [Backend (Flask)](#backend-flask)
3. [Frontend (Flutter)](#frontend-flutter)
4. [AI Providers](#ai-providers)
5. [Configuration Files](#configuration-files)
6. [Deployment Scripts](#deployment-scripts)
7. [Mobile Configuration](#mobile-configuration)

---

## Project Structure

```
```

## Backend (Flask)
## app.py

```
python

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
```

---

## models.py

```
python


from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import uuid
from cryptography.fernet import Fernet
import os

db = SQLAlchemy()

class UserSession(db.Model):
    __tablename__ = 'user_sessions'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_active = db.Column(db.DateTime, default=datetime.utcnow)
    conversation_count = db.Column(db.Integer, default=0)
    risk_level = db.Column(db.String(20), default='low')
    
class ConversationLog(db.Model):
    __tablename__ = 'conversation_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    provider = db.Column(db.String(20))
    risk_score = db.Column(db.Float, default=0.0)
    
class CrisisEvent(db.Model):
    __tablename__ = 'crisis_events'
    
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(36), db.ForeignKey('user_sessions.id'))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    risk_level = db.Column(db.String(20))
    intervention_taken = db.Column(db.String(100))
    escalated = db.Column(db.Boolean, default=False)
```

---

## crisis_detection.py

```
python

from textblob import TextBlob
import re
from datetime import datetime

def detect_crisis_level(message):
    """
    Analyze message for crisis indicators and return risk level and resources.
    """
    message = message.lower()
    
    # Crisis keywords
    high_risk_keywords = ['suicide', 'kill myself', 'want to die', 'end my life']
    medium_risk_keywords = ['hopeless', 'worthless', 'can\'t go on', 'give up']
    low_risk_keywords = ['sad', 'depressed', 'anxious', 'stressed']
    
    # Check for high risk
    if any(keyword in message for keyword in high_risk_keywords):
        return 'high', [
            'National Suicide Prevention Lifeline: 988',
            'Crisis Text Line: Text HOME to 741741',
            'Emergency: Call 911'
        ]
    
    # Check for medium risk
    if any(keyword in message for keyword in medium_risk_keywords):
        return 'medium', [
            'Crisis Text Line: Text HOME to 741741',
            'Find a Therapist: https://www.psychologytoday.com/us/therapists',
            'SAMHSA National Helpline: 1-800-662-4357'
        ]
    
    # Check for low risk
    if any(keyword in message for keyword in low_risk_keywords):
        return 'low', [
            'Find a Therapist: https://www.psychologytoday.com/us/therapists',
            'Mental Health Resources: https://www.nimh.nih.gov/health'
        ]
    
    return 'none', None
```

---

## requirements.txt

```
text

Flask==3.0.0
Flask-CORS==4.0.0
Flask-Limiter==3.5.0
Flask-SQLAlchemy==3.1.1
Flask-Session==0.5.0
python-dotenv==1.0.0
google-generativeai==0.3.2
openai==1.3.0
gunicorn==21.2.0
redis==5.0.1
psycopg[binary]==3.2.9```

---

## Dockerfile

```
text

# Use official Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install -U python-dotenv

# Copy project files
COPY . .

# Expose port (Flask default is 5000)
EXPOSE 5000

# Start the app with Gunicorn for production
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
```

---

## docker-compose.yml

```
yaml

services:
  web:
    build: .
    ports:
      - "5001:5000"
    environment:
      - ENVIRONMENT=docker
      - DATABASE_URL=postgresql://postgres:password@db:5432/myapp
      - REDIS_URL=redis://redis:6379/0
      - SECRET_KEY=your-secret-key
      - GEMINI_API_KEY=your-gemini-key
      - PPLX_API_KEY=your-pplx-key
    depends_on:
      - db
      - redis
    volumes:
      - .:/app

  db:
    image: postgres:15
    restart: always
    environment:
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=myapp
    volumes:
      - postgres_:/var/lib/postgresql/data

  redis:
    image: redis:7
    restart: always
    ports:
      - "6379:6379"

volumes:
  postgres_:
```

---

## startup.sh

```
bash

#!/bin/bash
# startup.sh - Script to start the Flask application on Render

echo "Starting AI Mental Health API..."

# Install dependencies
pip install -r requirements.txt

# Start the application with gunicorn
exec gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 8 --timeout 0 app:app ```

---

## dev_start.sh

```
bash

#!/bin/bash
# Development startup script

echo "🚀 Starting AI Mental Health API in development mode..."

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "📦 Activating virtual environment..."
    source venv/bin/activate
fi

# Install dependencies if needed
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Start the Flask development server
echo "🌐 Starting Flask development server..."
python app.py ```

---

## setup_local.py

```
python

#!/usr/bin/env python3
"""
Local Development Setup Script
Run this to set up the local development environment
"""

import os
import subprocess
import sys

def setup_local_env():
    """Set up local development environment"""
    print("🚀 Setting up local development environment...")
    
    # Create .env file for local development
    env_content = """# Local Development Environment
ENVIRONMENT=local
PORT=5050
SECRET_KEY=dev-secret-key-change-in-prod

# AI Provider Keys (add your actual keys)
GEMINI_API_KEY=AIzaSyCsHmnv7YH-gnSbfaVxXrO-xYardOeEiCw
OPENAI_API_KEY=your_openai_api_key_here
PPLX_API_KEY=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
AI_PROVIDER=gemini

# Local Development (no external services)
# DATABASE_URL=sqlite:///mental_health.db
# REDIS_URL= (leave empty for filesystem sessions)
"""
    
    with open('.env', 'w') as f:
        f.write(env_content)
    
    print("✅ Created .env file for local development")
    
    # Install dependencies
    print("📦 Installing Python dependencies...")
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-r', 'requirements.txt'])
    
    print("✅ Local development environment ready!")
    print("\n🎯 To start local development:")
    print("   python app.py")
    print("\n🌐 To start Flutter web app:")
    print("   cd ai_buddy_web && flutter run -d chrome")

if __name__ == "__main__":
    setup_local_env() ```

---

## AI Providers
## providers/gemini.py

```
python

import os
import google.generativeai as genai
from typing import Dict, List
from datetime import datetime, timedelta

# Store conversations with timestamp for cleanup
conversations: Dict[str, List[dict]] = {}
CONVERSATION_TIMEOUT = timedelta(hours=1)  # Clear conversations older than 1 hour

def cleanup_old_conversations():
    """Remove conversations that are older than the timeout"""
    current_time = datetime.now()
    to_remove = []
    for session_id in conversations:
        if conversations[session_id]:
            last_message_time = conversations[session_id][-1].get('timestamp')
            if last_message_time and current_time - last_message_time > CONVERSATION_TIMEOUT:
                to_remove.append(session_id)
    
    for session_id in to_remove:
        del conversations[session_id]

def get_gemini_response(message, mode='mental_health', session_id=None):
    """Get response from Gemini API with conversation history"""
    try:
        api_key = os.getenv('GEMINI_API_KEY')
        if not api_key:
            print("Gemini API key not found")
            return "Configuration error: Gemini API key not found"

        # Configure the API
        genai.configure(api_key=api_key)
        
        # Create the model
        try:
#            model = genai.GenerativeModel('models/gemini-1.5-flash-latest')
            model = genai.GenerativeModel('models/gemini-2.5-flash-lite')
        except Exception as e:
            print(f"Error creating Gemini model: {str(e)}")
            return f"Error initializing AI model: {str(e)}"
        
        # Initialize or get conversation history
        if session_id not in conversations:
            conversations[session_id] = []
        
        # Clean up old conversations periodically
        cleanup_old_conversations()
        
        # Prepare the conversation history
        history = conversations[session_id]
        
        # Prepare the prompt with context
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        # Build the conversation context
        conversation_context = ""
        if history:
            conversation_context = "\n".join([
                f"{'User' if msg['is_user'] else 'Assistant'}: {msg['content']}"
                for msg in history[-5:]  # Keep last 5 messages for context
            ])
            conversation_context = f"\nPrevious conversation:\n{conversation_context}\n"

        prompt = f"{system_message}\n{conversation_context}\nUser: {message}"
        
        # Generate response
        try:
            response = model.generate_content(prompt)
            if not response or not response.text:
                print("Empty response from Gemini")
                return "I received an empty response. Please try again."
            
            # Store the conversation
            history.append({
                'content': message,
                'is_user': True,
                'timestamp': datetime.now()
            })
            history.append({
                'content': response.text,
                'is_user': False,
                'timestamp': datetime.now()
            })
            conversations[session_id] = history
            
            return response.text
        except Exception as e:
            print(f"Error generating content: {str(e)}")
            return f"Error generating response: {str(e)}"

    except Exception as e:
        print(f"Unexpected Gemini API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
```

---

## providers/openai.py

```
python

import os
from openai import OpenAI

def get_openai_response(message, mode='mental_health'):
    """Get response from OpenAI API"""
    try:
        client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": message}
            ],
            max_tokens=150,
            temperature=0.7,
        )

        return response.choices[0].message.content

    except Exception as e:
        print(f"OpenAI API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
```

---

## providers/perplexity.py

```
python

import os
import requests

def get_perplexity_response(message, mode='mental_health'):
    """Get response from Perplexity API"""
    try:
        api_key = os.getenv('PERPLEXITY_API_KEY')
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
        }
        
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        data = {
            'model': 'mistral-7b-instruct',
            'messages': [
                {'role': 'system', 'content': system_message},
                {'role': 'user', 'content': message}
            ]
        }

        response = requests.post(
            'https://api.perplexity.ai/chat/completions',
            headers=headers,
            json=data
        )
        
        if response.status_code == 200:
            return response.json()['choices'][0]['message']['content']
        else:
            print(f"Perplexity API error: {response.status_code} - {response.text}")
            return "I'm having trouble connecting to my AI services. Please try again in a moment."

    except Exception as e:
        print(f"Perplexity API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
```

---

## Frontend (Flutter)
## ai_buddy_web/pubspec.yaml

```
yaml

name: ai_buddy_web
description: "AI-powered mental health and academic assistant"
# The following line prevents the package from being accidentally published to
# pub.dev using `flutter pub publish`. This is preferred for private packages.
publish_to: 'none' # Remove this line if you wish to publish to pub.dev

# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
# Both the version and the builder number may be overridden in flutter
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as versionCode.
# Read more about Android versioning at https://developer.android.com/studio/publish/versioning
# In iOS, build-name is used as CFBundleShortVersionString while build-number is used as CFBundleVersion.
# Read more about iOS versioning at
# https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
# In Windows, build-name is used as the major, minor, and patch parts
# of the product and file versions while build-number is used as the build suffix.
version: 1.0.0+1

environment:
  sdk: ^3.8.1

# Dependencies specify other packages that your package needs in order to work.
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  dio: ^5.4.1  # For API calls
  provider: ^6.1.2  # For state management
  shared_preferences: ^2.2.2  # For local storage
  intl: ^0.19.0  # For date formatting
  fl_chart: ^0.66.2  # For mood tracking charts
  url_launcher: ^6.2.5  # For opening crisis resource links
  flutter_markdown: ^0.6.20  # For rendering markdown in messages
  flutter_secure_storage: ^9.0.0  # For secure storage of session data
  animated_text_kit: ^4.2.2  # For typing animations

dev_dependencies:
  flutter_test:
    sdk: flutter

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^5.0.0

# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec

# The following section is specific to Flutter packages.
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true

  # To add assets to your application, add an assets section, like this:
  assets:
    - assets/images/
    - assets/icons/

  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images

  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
  #   - family: Trajan Pro
  #     fonts:
  #       - asset: fonts/TrajanPro.ttf
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package
```

---

## ai_buddy_web/lib/main.dart

```
dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/mood_provider.dart';
import 'widgets/chat_message_widget.dart';
import 'widgets/mood_tracker.dart';
import 'models/message.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MoodProvider()),
      ],
      child: MaterialApp(
        title: 'AI Mental Health Buddy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF667EEA),
            primary: const Color(0xFF667EEA),
            secondary: const Color(0xFFFF6B6B),
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showMoodTracker = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AI Mental Health Buddy'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showMoodTracker ? Icons.chat : Icons.mood),
            onPressed: () {
              setState(() {
                _showMoodTracker = !_showMoodTracker;
              });
            },
            tooltip: _showMoodTracker ? 'Show Chat' : 'Show Mood Tracker',
          ),
        ],
      ),
      body: _showMoodTracker
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: MoodTrackerWidget(),
            )
          : Column(
              children: [
                // Welcome message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Welcome to Your Safe Space',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Feel free to share your thoughts and feelings. I\'m here to listen and support you.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                // Chat messages
                Expanded(
                  child: Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: chatProvider.messages.length,
                        itemBuilder: (context, index) {
                          return ChatMessageWidget(
                            message: chatProvider.messages[index],
                          );
                        },
                      );
                    },
                  ),
                ),
                // Typing indicator
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    if (!chatProvider.isLoading) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('AI is typing...'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Input area
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, -2),
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Share your thoughts...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: _handleSubmitted,
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              _handleSubmitted(_messageController.text),
                          icon: const Icon(Icons.send),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }
}
```

---

## ai_buddy_web/lib/config/api_config.dart

```
dart

import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Development
  static const String localUrl = 'http://localhost:5058';
  
  // Production (Render)
  static const String productionUrl = 'https://ai-mental-health-assistant.onrender.com';
  
  // Get the appropriate URL based on environment
  static String get baseUrl {
    // For mobile apps, always use production URL
    if (!kIsWeb) {
      return productionUrl;
    }
    
    // For web, check if we're in production
    if (Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') {
      return productionUrl;
    }
    return localUrl;
  }
} ```

---

## ai_buddy_web/lib/services/api_service.dart

```
dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/message.dart';
import '../models/mood_entry.dart';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )),
        _storage = const FlutterSecureStorage();

  Future<void> _setupSession() async {
    String? sessionId = await _storage.read(key: 'session_id');
    if (sessionId == null) {
      // Get new session from backend
      final response = await _dio.get('/get_or_create_session');
      sessionId = response.data['session_id'];
      await _storage.write(key: 'session_id', value: sessionId);
    }
    // Add session ID to all requests
    _dio.options.headers['X-Session-ID'] = sessionId;
  }

  Future<Message> sendMessage(String content) async {
    await _setupSession();
    try {
      final response = await _dio.post('/chat', data: {
        'message': content,
        'mode': 'mental_health', // Always use mental health mode for now
      });

      if (response.data['error'] != null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/chat'),
          error: response.data['error'],
        );
      }

      // Extract risk level and resources if present
      String riskLevel = 'none';
      List<String>? resources;
      
      if (response.data['risk_level'] != null) {
        riskLevel = response.data['risk_level'].toString().toLowerCase();
      }
      
      if (response.data['resources'] != null) {
        resources = List<String>.from(response.data['resources']);
      }

      final message = Message(
        content: response.data['response'] ?? response.data['message'] ?? 'No response received',
        isUser: false,
        riskLevel: RiskLevel.values.firstWhere(
          (e) => e.toString().split('.').last == riskLevel,
          orElse: () => RiskLevel.none,
        ),
        resources: resources,
      );

      return message;
    } on DioException catch (e) {
      print('Error sending message: ${e.message}');
      print('Error response: ${e.response?.data}');
      return Message(
        content: e.response?.data?['error'] ?? 'An error occurred while communicating with the AI. Please try again.',
        isUser: false,
        type: MessageType.error,
      );
    } catch (e) {
      print('Unexpected error: $e');
      return Message(
        content: 'An unexpected error occurred. Please try again.',
        isUser: false,
        type: MessageType.error,
      );
    }
  }

  Future<List<MoodEntry>> getMoodHistory() async {
    await _setupSession();
    try {
      final response = await _dio.get('/mood_history');
      return (response.data as List)
          .map((json) => MoodEntry.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting mood history: $e');
      return [];
    }
  }

  Future<MoodEntry> addMoodEntry(MoodEntry entry) async {
    await _setupSession();
    try {
      final response = await _dio.post('/mood_entry', data: entry.toJson());
      return MoodEntry.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? 'Failed to save mood entry');
    }
  }

  Future<List<Message>> getChatHistory() async {
    await _setupSession();
    try {
      final response = await _dio.get('/chat_history');
      return (response.data as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting chat history: $e');
      return [];
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'session_id');
  }
} ```

---

## ai_buddy_web/lib/models/message.dart

```
dart

import 'package:flutter/material.dart';

enum MessageType { text, error, system }
enum RiskLevel { none, low, medium, high }

class Message {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;
  final RiskLevel riskLevel;
  final List<String>? resources;

  Message({
    String? id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.type = MessageType.text,
    this.riskLevel = RiskLevel.none,
    this.resources,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String?,
      content: json['content'] as String,
      isUser: json['is_user'] as bool,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type'] ?? 'text'}',
        orElse: () => MessageType.text,
      ),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString() == 'RiskLevel.${json['risk_level'] ?? 'none'}',
        orElse: () => RiskLevel.none,
      ),
      resources: (json['resources'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'risk_level': riskLevel.toString().split('.').last,
      'resources': resources,
    };
  }

  Color getMessageColor(BuildContext context) {
    if (type == MessageType.error) {
      return Theme.of(context).colorScheme.error;
    }
    if (type == MessageType.system) {
      return Theme.of(context).colorScheme.surfaceVariant;
    }
    return isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondaryContainer;
  }

  Color getTextColor(BuildContext context) {
    if (type == MessageType.error) {
      return Theme.of(context).colorScheme.onError;
    }
    if (type == MessageType.system) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSecondaryContainer;
  }
} ```

---

## ai_buddy_web/lib/models/mood_entry.dart

```
dart

class MoodEntry {
  final String id;
  final DateTime timestamp;
  final int moodLevel; // 1-5: 1=very bad, 5=very good
  final String? note;

  MoodEntry({
    String? id,
    required this.moodLevel,
    this.note,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now(),
        assert(moodLevel >= 1 && moodLevel <= 5, 'Mood level must be between 1 and 5');

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String?,
      moodLevel: json['mood_level'] as int,
      note: json['note'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mood_level': moodLevel,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get moodEmoji {
    switch (moodLevel) {
      case 1:
        return '😢';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😊';
      default:
        return '❓';
    }
  }

  String get moodDescription {
    switch (moodLevel) {
      case 1:
        return 'Very Bad';
      case 2:
        return 'Bad';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Very Good';
      default:
        return 'Unknown';
    }
  }
} ```

---

## ai_buddy_web/lib/providers/chat_provider.dart

```
dart

import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  ChatProvider() : _apiService = ApiService() {
    _loadChatHistory();
  }

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadChatHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = await _apiService.getChatHistory();
      _messages.clear();
      _messages.addAll(history);
    } catch (e) {
      _error = 'Failed to load chat history';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = Message(
      content: content,
      isUser: true,
    );

    _messages.add(userMessage);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final aiMessage = await _apiService.sendMessage(content);
      _messages.add(aiMessage);
      _error = null;
    } catch (e) {
      _error = 'Failed to send message';
      _messages.add(Message(
        content: 'Failed to get response. Please try again.',
        isUser: false,
        type: MessageType.error,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _apiService.clearSession();
    notifyListeners();
  }
} ```

---

## ai_buddy_web/lib/providers/mood_provider.dart

```
dart

import 'package:flutter/material.dart';
import '../models/mood_entry.dart';
import '../services/api_service.dart';

class MoodProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<MoodEntry> _moodEntries = [];
  bool _isLoading = false;
  String? _error;

  MoodProvider() : _apiService = ApiService() {
    _loadMoodHistory();
  }

  List<MoodEntry> get moodEntries => List.unmodifiable(_moodEntries);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadMoodHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _moodEntries = await _apiService.getMoodHistory();
      _error = null;
    } catch (e) {
      _error = 'Failed to load mood history';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMoodEntry(int moodLevel, {String? note}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final entry = MoodEntry(
        moodLevel: moodLevel,
        note: note,
      );
      final savedEntry = await _apiService.addMoodEntry(entry);
      _moodEntries = [..._moodEntries, savedEntry];
      _error = null;
    } catch (e) {
      _error = 'Failed to save mood entry';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double get averageMood {
    if (_moodEntries.isEmpty) return 0;
    final sum = _moodEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.moodLevel,
    );
    return sum / _moodEntries.length;
  }

  List<MoodEntry> getMoodEntriesForDate(DateTime date) {
    return _moodEntries.where((entry) {
      return entry.timestamp.year == date.year &&
          entry.timestamp.month == date.month &&
          entry.timestamp.day == date.day;
    }).toList();
  }

  Map<DateTime, List<MoodEntry>> get moodEntriesByDate {
    final map = <DateTime, List<MoodEntry>>{};
    for (final entry in _moodEntries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      map.putIfAbsent(date, () => []).add(entry);
    }
    return map;
  }
} ```

---

## ai_buddy_web/lib/widgets/chat_message_widget.dart

```
dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import 'crisis_resources.dart';

class ChatMessageWidget extends StatelessWidget {
  final Message message;

  const ChatMessageWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isUser) _buildAvatar(context),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.getMessageColor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: message.getTextColor(context)),
                      a: TextStyle(
                        color: message.isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (message.isUser) _buildAvatar(context),
            ],
          ),
          if (message.riskLevel != RiskLevel.none && !message.isUser)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: CrisisResourcesWidget(riskLevel: message.riskLevel),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      backgroundColor: message.isUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
      child: Text(
        message.isUser ? '👤' : '🤖',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
} ```

---

## Configuration Files
## .gitignore

```
text

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
ENV/
.env

# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
.metadata
*.iml
.idea/
.vscode/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# IDE
*.swp
*.swo
*~

# Logs
*.log
logs/

# Local development
instance/
.webassets-cache
.env.local
.env.development.local
.env.test.local
.env.production.local

# Dependencies
node_modules/
jspm_packages/```

---

## README.md

```
markdown

---

# AI-MVP-Backend

A modular Flask API backend that lets you access multiple AI providers (Gemini, Perplexity, and more) with a single `/chat` endpoint.

---

## **Features**

- Supports Google Gemini and Perplexity AI providers (easy to extend for OpenAI, Hugging Face, etc.)
- Simple `/chat` endpoint for unified prompt/response
- Environment variable-based API key management
- Modular provider code for easy swapping or extension
- Logging and error handling included

---

## **Project Structure**

```
.
├── app.py
├── .env
├── requirements.txt
├── /providers
│   ├── __init__.py
│   ├── gemini.py
│   ├── perplexity.py
│   ├── openai.py
│   └── huggingface.py
└── README.md
```

---

## **Setup Instructions**

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd ai-mvp-backend
   ```

2. **Create and activate a virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure your `.env` file**  
   Create a `.env` file in the project root with your API keys:
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   PPLX_API_KEY=your_perplexity_api_key_here
   # Add other keys as needed
   ```

5. **Run the Flask app**
   ```bash
   python app.py
   ```
   The server will run at [http://127.0.0.1:5000](http://127.0.0.1:5000).

---

## **Usage**

### **Send a Chat Request**

**Endpoint:**  
`POST /chat`

**Request Body Example:**
```json
{
  "prompt": "Hello, AI!",
  "provider": "gemini"
}
```
or
```json
{
  "prompt": "Hello, AI!",
  "provider": "perplexity"
}
```

**Curl Example:**
```bash
curl -X POST http://127.0.0.1:5000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello from Gemini!","provider":"gemini"}'
```

---

## **Adding More Providers**

- Implement a new provider class in `/providers/`.
- Update the `get_provider` function in `app.py` to support the new provider.
- Add the required API key to your `.env`.

---

## **Logging and Error Handling**

- All requests and responses are logged to the console for easy debugging.
- Errors are returned as JSON with an `"error"` field and logged for review.

---

## **License**

None

---

---

## **Root Cause**
Somewhere in your code, a bytes object is being stored in the session (most likely `session['session_id']`). Flask/werkzeug expects cookie values to be strings, not bytes.

---

## **How to Fix**

### 1. **Force Session Values to be Strings**
In your `get_or_create_session()` function in `app.py`, make sure you always store a string, not bytes:

**Find this code:**
```python
if 'session_id' not in session:
    session['session_id'] = str(uuid.uuid4())
    # ... rest of code ...
```
**If you ever decode or encode session values, make sure you use `.decode()` or `.encode()` appropriately.**

### 2. **Patch: Always Store as String**
To be extra safe, you can update the assignment to:
```python
session['session_id'] = str(session['session_id']) if isinstance(session.get('session_id'), bytes) else session.get('session_id', str(uuid.uuid4()))
```
But the original code should already store a string, so check if anywhere else you are putting a bytes value in the session.

---

## **Quick Diagnostic**
- Add a debug print right after setting the session:
  ```python
  print("session_id type:", type(session['session_id']))
  ```
- Restart your app and try the `/chat` endpoint again. If you see `<class 'bytes'>`, something is storing bytes instead of a string.

---

## **Summary**
- The error is caused by storing a bytes object in the session.
- Make sure all session values (especially `session['session_id']`) are always strings.

Would you like me to provide a code patch for your `app.py` to ensure this?```

---

## ai_buddy_web/README.md

```
markdown

# ai_buddy_web

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
```

---

## Deployment Scripts
## ai_buddy_web/build_android.sh

```
bash

#!/bin/bash
# Android Build Script for AI Mental Health Buddy

echo "🤖 Building Android APK..."

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

echo "✅ Android APK built successfully!"
echo "📱 APK location: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "🚀 Next steps:"
echo "1. Test the APK: flutter install"
echo "2. Upload to Google Play Console"
echo "3. Or distribute via direct download" ```

---

## ai_buddy_web/build_ios.sh

```
bash

#!/bin/bash
# iOS Build Script for AI Mental Health Buddy

echo "🍎 Building iOS App..."

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release iOS app
flutter build ios --release

echo "✅ iOS app built successfully!"
echo "📱 App location: build/ios/iphoneos/Runner.app"
echo ""
echo "🚀 Next steps:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Archive the app in Xcode"
echo "3. Upload to App Store Connect"
echo "4. Or distribute via TestFlight" ```

---

## setup_mobile.sh

```
bash

#!/bin/bash
# Mobile Development Setup Script

echo "📱 Setting up mobile development environment..."

# Check if Android Studio is installed
if [ -d "/Applications/Android Studio.app" ]; then
    echo "✅ Android Studio is installed"
else
    echo "❌ Android Studio not found. Please install it from:"
    echo "   https://developer.android.com/studio"
    echo "   Or run: brew install --cask android-studio"
fi

# Check if Xcode is installed
if xcode-select -p &> /dev/null; then
    echo "✅ Xcode command line tools are installed"
else
    echo "❌ Xcode command line tools not found. Run:"
    echo "   xcode-select --install"
fi

# Check CocoaPods
if command -v pod &> /dev/null; then
    echo "✅ CocoaPods is installed"
else
    echo "❌ CocoaPods not found. Run:"
    echo "   sudo gem install cocoapods"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Open Android Studio and complete the setup wizard"
echo "2. Install Android SDK through Android Studio"
echo "3. Run: flutter doctor"
echo "4. Run: flutter config --android-sdk /path/to/android/sdk"
echo ""
echo "📱 To test mobile builds:"
echo "   cd ai_buddy_web"
echo "   flutter run -d android  # For Android"
echo "   flutter run -d ios      # For iOS" ```

---

## Mobile Configuration
## ai_buddy_web/android/app/build.gradle.kts

```
text

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.ai_buddy_web"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.example.ai_buddy_web"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:${kotlin.version}")
}
```

---

## ai_buddy_web/ios/Runner/Info.plist

```
xml

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>AI Mental Health Buddy</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>ai_buddy_web</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UIViewControllerBasedStatusBarAppearance</key>
	<false/>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
</dict>
</plist>
```

---

