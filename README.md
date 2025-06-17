---

# AI-MVP-Backend

A modular Flask API backend that lets you access multiple AI providers (Gemini, Perplexity, and more) with a single `/chat` endpoint.

---

## **Features**

- Supports Google Gemini and Perplexity AI providers (easy to extend for OpenAI, Hugging Face, etc.)
- Simple `/chat` endpoint for unified prompt/response
- Environment variable-based API key management
- Modular provider code for easy swapping or extension
- Logging and error handling included

---

## **Project Structure**

```
.
├── app.py
├── .env
├── requirements.txt
├── /providers
│   ├── __init__.py
│   ├── gemini.py
│   ├── perplexity.py
│   ├── openai.py
│   └── huggingface.py
└── README.md
```

---

## **Setup Instructions**

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd ai-mvp-backend
   ```

2. **Create and activate a virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure your `.env` file**  
   Create a `.env` file in the project root with your API keys:
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   PPLX_API_KEY=your_perplexity_api_key_here
   # Add other keys as needed
   ```

5. **Run the Flask app**
   ```bash
   python app.py
   ```
   The server will run at [http://127.0.0.1:5000](http://127.0.0.1:5000).

---

## **Usage**

### **Send a Chat Request**

**Endpoint:**  
`POST /chat`

**Request Body Example:**
```json
{
  "prompt": "Hello, AI!",
  "provider": "gemini"
}
```
or
```json
{
  "prompt": "Hello, AI!",
  "provider": "perplexity"
}
```

**Curl Example:**
```bash
curl -X POST http://127.0.0.1:5000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello from Gemini!","provider":"gemini"}'
```

---

## **Adding More Providers**

- Implement a new provider class in `/providers/`.
- Update the `get_provider` function in `app.py` to support the new provider.
- Add the required API key to your `.env`.

---

## **Logging and Error Handling**

- All requests and responses are logged to the console for easy debugging.
- Errors are returned as JSON with an `"error"` field and logged for review.

---

## **License**

MIT

---