import requests

class PerplexityProvider:
    def __init__(self, api_key, model="sonar-medium-online"):
        self.api_key = api_key
        self.model = model

    def chat(self, prompt, history=None):
        url = "https://api.perplexity.ai/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        # Perplexity expects a list of messages for chat
        messages = (history or []) + [{"role": "user", "content": prompt}]
        payload = {
            "model": self.model,
            "messages": messages
        }
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]
