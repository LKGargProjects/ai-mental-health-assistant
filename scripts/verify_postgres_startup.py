#!/usr/bin/env python3
"""
Verify Flask backend startup diagnostics with PostgreSQL.
- Sets AI_DEBUG_LOGS=true and LOG_LEVEL=INFO
- Uses DATABASE_URL from env or a sane local default
- Sets Redis URL and dummy AI keys
- Imports app to trigger startup and prints a brief summary

Usage:
  python3 scripts/verify_postgres_startup.py

Optionally override via env:
  DATABASE_URL, AI_PROVIDER, GEMINI_API_KEY, OPENAI_API_KEY, PPLX_API_KEY
"""
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Ensure repository root is on sys.path so we can import app.py at the root
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Load .env first so user-provided values take precedence over script defaults
load_dotenv(override=False)

# Logging and debug flags
os.environ.setdefault('AI_DEBUG_LOGS', 'true')
os.environ.setdefault('LOG_LEVEL', 'INFO')

# Database and Redis
os.environ.setdefault('DATABASE_URL', 'postgresql+psycopg://ai_buddy:ai_buddy_password@localhost:5432/mental_health')
os.environ.setdefault('REDIS_URL', 'redis://localhost:6379')

# AI provider setup (dummy keys are fine for startup diagnostics)
os.environ.setdefault('GEMINI_API_KEY', 'dummy-gemini-key')
os.environ.setdefault('OPENAI_API_KEY', 'dummy-openai-key')
os.environ.setdefault('PPLX_API_KEY', 'dummy-pplx-key')
os.environ.setdefault('AI_PROVIDER', os.getenv('AI_PROVIDER', 'gemini'))

# Import the app to trigger create_app() and startup logs
import app  # noqa: F401

print("\n[verify] App startup verification complete.")
print("[verify] AI_PROVIDER:", app.app.config.get('AI_PROVIDER'))
print("[verify] SQLALCHEMY_DATABASE_URI:", app.app.config.get('SQLALCHEMY_DATABASE_URI'))
