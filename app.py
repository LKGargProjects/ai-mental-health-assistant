from flask import Flask, request, jsonify
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Import only GeminiProvider for now
from providers.gemini import GeminiProvider

app = Flask(__name__)

# Get API keys from environment
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Only GeminiProvider is active for now
def get_provider(provider_name):
    # Only Gemini is active; others can be uncommented later
    if provider_name == "gemini":
        return GeminiProvider(GEMINI_API_KEY)
    else:
        raise ValueError(f"Provider '{provider_name}' is not active.")

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    prompt = data.get("prompt", "")
    history = data.get("history", [])
    provider_name = data.get("provider", "gemini")
    try:
        provider = get_provider(provider_name)
        answer = provider.chat(prompt, history)
        return jsonify({"answer": answer})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)
