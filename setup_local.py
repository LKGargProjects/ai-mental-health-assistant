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
    setup_local_env() 