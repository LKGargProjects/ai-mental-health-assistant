import requests

# Perplexity API function commented out
'''
def ask_perplexity(prompt, api_key, model='sonar-pro'):
    ...
'''

def ask_gemini(prompt, api_key, model='models/gemini-1.5-pro-latest'):
    url = f"https://generativelanguage.googleapis.com/v1beta/{model}:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code == 429:
        return {
            "error": "Quota exceeded. Please wait and try again later.",
            "details": response.text
        }
    try:
        return response.json()
    except Exception as e:
        return {
            "error": f"JSON decode error: {e}",
            "status_code": response.status_code,
            "response_text": response.text
        }

if __name__ == "__main__":
    GEMINI_API_KEY = "AIzaSyCsHmnv7YH-gnSbfaVxXrO-xYardOeEiCw"  # <--- Replace with your valid key from AI Studio
    prompt = "Summarize the latest AI trends."

    gemini_result = ask_gemini(
        prompt,
        GEMINI_API_KEY,
        model='models/gemini-1.5-flash-latest'
    )

    print("Gemini API response:", gemini_result)
