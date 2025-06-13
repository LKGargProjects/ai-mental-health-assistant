import google.generativeai as genai

class GeminiProvider:
    def __init__(self, api_key, model="models/gemini-1.5-flash-latest"):
        genai.configure(api_key=api_key)
        self.model = model

    def chat(self, prompt, history=None):
        model = genai.GenerativeModel(self.model)
        chat = model.start_chat(history=history or [])
        response = chat.send_message(prompt)
        return response.text
