import requests

def ask_gemini(prompt, api_key, model='models/gemini-1.5-flash-latest'):
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
        json_response = response.json()
        # Extract the main text answer if available
        if (
            'candidates' in json_response
            and isinstance(json_response['candidates'], list)
            and len(json_response['candidates']) > 0
            and 'content' in json_response['candidates'][0]
            and 'parts' in json_response['candidates'][0]['content']
            and len(json_response['candidates'][0]['content']['parts']) > 0
            and 'text' in json_response['candidates'][0]['content']['parts'][0]
        ):
            answer = json_response['candidates'][0]['content']['parts'][0]['text']
            return {"answer": answer}
        return json_response
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

    if "answer" in gemini_result:
        print("Gemini AI Answer:\n", gemini_result["answer"])
    else:
        print("Gemini API response:", gemini_result)
