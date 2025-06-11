import requests

# Perplexity API
# Available models: 'gemini-2', 'sonar-pro', 'o1', 'gpt-4', etc.
def ask_perplexity(prompt, api_key, model='gemini-2'):
    url = "https://api.perplexity.ai/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {
        "model": model,  # Choose model here: 'gemini-2', 'sonar-pro', 'o1', 'gpt-4', etc.
        "messages": [
            {"role": "user", "content": prompt}
        ]
    }
    response = requests.post(url, headers=headers, json=payload)
    return response.json()

# Gemini API (Google)
# Available models: 'gemini-pro', 'gemini-2.5-pro', 'gemini-flash', etc.
def ask_gemini(prompt, api_key, model='gemini-pro'):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }
    response = requests.post(url, headers=headers, json=payload)
    return response.json()

# Usage examples:
# To use a different model, just change the 'model' argument below.
perplexity_result = ask_perplexity(
    "Summarize the latest AI trends.",
    "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",
    model='sonar-pro'  # Try 'gemini-2', 'o1', 'gpt-4', etc.
)

gemini_result = ask_gemini(
    "Summarize the latest AI trends.",
    "AIzaSyCsHmnv7YH-gnSbfaVxXrO-xYardOeEiCw",
    model='gemini-flash'  # Try 'gemini-pro', 'gemini-flash', 'gemini-2.5-pro' etc.
)

print("Perplexity API response:", perplexity_result)
print("Gemini API response:", gemini_result)
