from flask import Flask, request, jsonify
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

from providers.gemini import GeminiProvider
from providers.perplexity import PerplexityProvider

# --- Add these imports for rate limiting ---
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-key-change-in-prod') # 'dev-key-change-in-prod' is a fallback for local/dev only
#app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev')  # 'dev' is a fallback for local/dev only

# --- Rate Limiting Setup ---
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["100 per day", "20 per hour"],  # Adjust as needed
    storage_uri="memory://"
)

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

# --- Apply rate limiting to the /chat endpoint ---
@app.route("/chat", methods=["POST"])
@limiter.limit("10 per minute")  # Custom limit for /chat endpoint
def chat():
    data = request.get_json()
    prompt = data.get("prompt", "")
    history = data.get("history", [])
    provider_name = data.get("provider", "gemini")
    try:
        provider = get_provider(provider_name)
        answer = provider.chat(prompt, history)
        app.logger.info(f"Prompt: {prompt}, Provider: {provider_name}, Answer: {answer[:80]}")
        return jsonify({"answer": answer})
    except Exception as e:
        app.logger.error(f"Error in /chat: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)

# ... all your Flask code above ...

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
