import os
import re
import random
import threading
import time
import hashlib
import google.generativeai as genai
from typing import Dict, List
from datetime import datetime, timedelta

# Store conversations with timestamp for cleanup
conversations: Dict[str, List[dict]] = {}
CONVERSATION_TIMEOUT = timedelta(hours=1)  # Clear conversations older than 1 hour

# ---------- Gemini multi-key + resilience helpers (single-file, surgical) ----------

# Parse keys from env with minimal churn: support CSV in GEMINI_API_KEY and alias GEMINI_API_KEYS
def _parse_api_keys() -> List[str]:
    keys: List[str] = []
    raw_primary = os.getenv('GEMINI_API_KEY') or ''
    raw_alias = os.getenv('GEMINI_API_KEYS') or ''
    # CSV support in both vars
    parts: List[str] = []
    parts += [p.strip() for p in raw_primary.split(',') if p.strip()]
    parts += [p.strip() for p in raw_alias.split(',') if p.strip()]
    # De-duplicate while preserving order
    seen = set()
    for k in parts:
        if k not in seen:
            seen.add(k)
            keys.append(k)
    return keys

_GEMINI_KEYS: List[str] = _parse_api_keys()

# Round-robin pointer
_key_lock = threading.Lock()
_key_index = 0

def _next_key_index() -> int:
    global _key_index
    with _key_lock:
        idx = _key_index
        if _GEMINI_KEYS:
            _key_index = (_key_index + 1) % len(_GEMINI_KEYS)
        return idx

# In-memory blocklist to skip exhausted keys for a while
_BLOCK_TTL_HOURS = 6
_blocked_until: Dict[int, datetime] = {}

# Last-good model per key for snappier first token
_last_good_model: Dict[int, str] = {}

def _debug_enabled() -> bool:
    return (os.getenv('AI_DEBUG_LOGS') or '').lower() == 'true'

def _debug(*args):
    if _debug_enabled():
        print('[gemini]', *args)

def _should_rotate_key(err: Exception) -> bool:
    """Rotate only on quota/auth/rate-limit/permission errors."""
    msg = ''
    try:
        msg = (str(err) or '').lower()
    except Exception:
        pass
    if any(tok in msg for tok in (
        'quota', 'rate limit', 'ratelimit', 'permission', 'unauthorized',
        'forbidden', 'api key', 'key invalid', 'invalid key', 'exceeded'
    )):
        return True
    status = getattr(err, 'status', None) or getattr(err, 'code', None)
    if status in (401, 403, 429):
        return True
    # Explicit string 429
    if '429' in msg:
        return True
    return False

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

def get_gemini_response(message, mode='mental_health', session_id=None, risk_level=None):
    """Get response from Gemini API with conversation history, with model-first fallback and smart multi-key rotation."""
    try:
        if not _GEMINI_KEYS:
            print("Gemini API key not found")
            return "Configuration error: Gemini API key not found"

        # Initialize or get conversation history
        if session_id not in conversations:
            conversations[session_id] = []

        # Clean up old conversations periodically
        cleanup_old_conversations()

        # For crisis-related messages, clear history to avoid AI learning crisis resources
        crisis_keywords = ['die', 'suicide', 'kill myself', 'end my life', 'take my life', 'want to die']
        is_crisis_message = any(keyword in (message or '').lower() for keyword in crisis_keywords)

        if is_crisis_message:
            history = []
            conversations[session_id] = []
        else:
            history = conversations[session_id]

        # Prepare the prompt with context based on risk level
        if risk_level == 'crisis':
            system_message = """You are a supportive AI assistant for high school students. 
            The user is in crisis and needs immediate emotional support.
            Respond with empathy, understanding, and emotional support ONLY.
            Do NOT mention any crisis resources, helpline numbers, or specific actions.
            Focus on emotional support and being present with the user.
            Crisis resources will be provided separately by the system."""
        else:
            system_message = """You are a supportive AI assistant for high school students. 
            Respond with empathy and understanding. If the user seems distressed, 
            provide emotional support and suggest healthy coping strategies. 
            Keep responses concise and focused.
            
            ABSOLUTE RULE: You must NEVER mention any crisis helpline numbers, phone numbers, or specific resources.
            Examples of what NOT to mention: 988, 111, 741741, "National Suicide Prevention Lifeline", "Crisis Text Line", etc.
            Crisis resources will be provided separately by the system.
            Focus ONLY on emotional support, understanding, and general guidance.
            If you mention any crisis resources, you are violating this rule."""

        # Build the conversation context
        conversation_context = ""
        if history:
            conversation_context = "\n".join([
                f"{'User' if msg['is_user'] else 'Assistant'}: {msg['content']}"
                for msg in history[-5:]
            ])
            conversation_context = f"\nPrevious conversation:\n{conversation_context}\n"

        prompt = f"{system_message}\n{conversation_context}\nUser: {message}"

        # Model fallback order (best first) - use broadly compatible identifiers
        # Prefer newer 2.5 flash models, then 2.0, then stable 1.5 variants, then older names
        default_models = [
            'gemini-2.5-flash',
            'gemini-2.5-flash-lite',
            'gemini-2.0-flash',
            'gemini-1.5-flash',
            'gemini-1.5-flash-latest',
            'gemini-1.5-flash-8b',
            'gemini-1.5-pro',
            'gemini-pro',
        ]

        # Outer loop over keys with round-robin start; skip blocked keys
        now = datetime.now()
        # Sticky session: choose starting key by hashing session_id, else fall back to round-robin
        if len(_GEMINI_KEYS) > 1:
            if session_id:
                try:
                    hval = int(hashlib.sha256(session_id.encode('utf-8')).hexdigest(), 16)
                    start_idx = hval % len(_GEMINI_KEYS)
                except Exception:
                    start_idx = _next_key_index()
            else:
                start_idx = _next_key_index()
        else:
            start_idx = 0
        last_error = None

        for k_off in range(len(_GEMINI_KEYS)):
            key_idx = (start_idx + k_off) % len(_GEMINI_KEYS)

            # Skip blocked keys within TTL window
            until = _blocked_until.get(key_idx)
            if until and now < until:
                _debug(f"skip_blocked key_index={key_idx} until={until}")
                continue

            api_key = _GEMINI_KEYS[key_idx]
            try:
                genai.configure(api_key=api_key)
                _debug(f"using_key_index={key_idx}")

                # Build model order, trying last-good first if present
                models_order = list(default_models)
                if key_idx in _last_good_model:
                    lgm = _last_good_model[key_idx]
                    if lgm in models_order:
                        models_order = [lgm] + [m for m in models_order if m != lgm]

                for model_name in models_order:
                    try:
                        model = genai.GenerativeModel(model_name)
                        response = model.generate_content(prompt)
                        if not response or not getattr(response, 'text', None):
                            _debug(f"empty_response model={model_name}")
                            last_error = ValueError('empty response')
                            # Try next model within same key
                            continue

                        # Build cleaned response
                        if risk_level == 'crisis':
                            cleaned_response = (
"""I hear how much pain you're in, and it takes incredible strength to express these feelings. Please know that you're not alone, and there are people who want to help you through this difficult time.

Your feelings are valid, and it's okay to not be okay. You don't have to carry this burden alone. There are people who care about you and want to support you.

Please remember that these intense feelings can pass, and there is hope for things to get better. You deserve support and care."""
                            )
                        else:
                            cleaned_response = response.text

                        # Clean up formatting
                        cleaned_response = re.sub(r'\n\s*\n\s*\n', '\n\n', cleaned_response).strip()

                        # Store conversation
                        history.append({'content': message, 'is_user': True, 'timestamp': datetime.now()})
                        history.append({'content': cleaned_response, 'is_user': False, 'timestamp': datetime.now()})
                        conversations[session_id] = history

                        # Update last-good model for this key
                        _last_good_model[key_idx] = model_name

                        return cleaned_response
                    except Exception as e_model:
                        rotate = _should_rotate_key(e_model)
                        _debug(f"model_error model={model_name} rotate={rotate} err={e_model}")
                        last_error = e_model
                        if rotate:
                            # Block this key for TTL and rotate to next key
                            _blocked_until[key_idx] = datetime.now() + timedelta(hours=_BLOCK_TTL_HOURS)
                            _debug(f"block_key key_index={key_idx} ttl_hours={_BLOCK_TTL_HOURS}")
                            break
                        # else: try next model under same key
                        continue

            except Exception as e_key:
                # Configuration or immediate key-scope errors
                rotate = _should_rotate_key(e_key)
                _debug(f"key_scope_error key_index={key_idx} rotate={rotate} err={e_key}")
                last_error = e_key
                if rotate:
                    _blocked_until[key_idx] = datetime.now() + timedelta(hours=_BLOCK_TTL_HOURS)
                    _debug(f"block_key key_index={key_idx} ttl_hours={_BLOCK_TTL_HOURS}")

            # Small jitter when rotating keys to avoid synchronized spikes
            time.sleep(random.uniform(0.05, 0.2))

        # If all keys/models failed
        if last_error:
            return f"Error generating response: {str(last_error)}"
        return "I'm having trouble connecting to my AI services. Please try again in a moment."

    except Exception as e:
        print(f"Unexpected Gemini API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
