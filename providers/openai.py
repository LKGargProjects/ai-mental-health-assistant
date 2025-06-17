import openai

class OpenAIProvider:
    def __init__(self, api_key, model="gpt-4o"):
        openai.api_key = api_key
        self.model = model

    def chat(self, prompt, history=None):
        # OpenAI expects a list of messages for chat
        messages = (history or []) + [{"role": "user", "content": prompt}]
        response = openai.ChatCompletion.create(
            model=self.model,
            messages=messages
        )
        return response.choices[0].message.content
