import requests
import os

class PerplexityProvider:
    def __init__(self, api_key=None, model="sonar"):
        # Load API key from argument or environment variable
        self.api_key = api_key or os.getenv("PPLX_API_KEY")
        self.model = model
        self.base_url = "https://api.perplexity.ai/chat/completions"
        # Debug print: Check the actual API key being used (remove/comment after debugging)
        print("DEBUG: Using Perplexity API Key:", repr(self.api_key))

    def chat(self, prompt, history=None):
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            # User-Agent: Mimic curl to avoid API blocking Python requests (keep for now)
            "User-Agent": "curl/7.88.1"
        }
        messages = (history or []) + [{"role": "user", "content": prompt}]
        payload = {
            "model": self.model,
            "messages": messages
        }
        # Debug prints: Show headers and payload being sent (remove/comment after debugging)
        print("DEBUG: Headers:", headers)
        print("DEBUG: Payload:", payload)

        response = requests.post(self.base_url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]
