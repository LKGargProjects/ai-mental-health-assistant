import requests

# --------- Perplexity API Function ---------
def ask_perplexity(prompt, api_key, model='sonar-pro'):
    url = "https://api.perplexity.ai/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {
        "model": model,  # Try 'sonar-pro', 'gemini-2', 'o1', 'gpt-4', etc.
        "messages": [
            {"role": "user", "content": prompt}
        ]
    }
    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {"error": str(e), "response_text": getattr(response, "text", "")}

# --------- Gemini API Function (with error handling) ---------
def ask_gemini(prompt, api_key, model='models/gemini-1.5-pro-latest'):
    url = f"https://generativelanguage.googleapis.com/v1beta/{model}:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }
    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        try:
            return response.json()
        except Exception as e:
            return {
                "error": f"JSON decode error: {e}",
                "status_code": response.status_code,
                "response_text": response.text
            }
    except Exception as e:
        return {
            "error": f"HTTP error: {e}",
            "response_text": getattr(response, "text", "")
        }

# --------- MAIN TEST ---------
if __name__ == "__main__":
    # Replace with your actual keys!
    PPLX_API_KEY = "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"
    GEMINI_API_KEY = "AIzaSyCsHmnv7YH-gnSbfaVxXrO-xYardOeEiCw"

    prompt = "Summarize the latest AI trends."

    # Test Perplexity
    perplexity_result = ask_perplexity(
        prompt,
        PPLX_API_KEY,
        model='sonar-pro'  # or 'gemini-2', 'o1', 'gpt-4', etc.
    )
    print("Perplexity API response:")
    print(perplexity_result)
    print("-" * 60)

    # Test Gemini
    gemini_result = ask_gemini(
        prompt,
        GEMINI_API_KEY,
        model='models/gemini-1.5-pro-latest'  # or 'models/gemini-1.5-flash-latest'
    )
    print("Gemini API response:")
    print(gemini_result)
