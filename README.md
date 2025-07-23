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

None

---

---

## **Root Cause**
Somewhere in your code, a bytes object is being stored in the session (most likely `session['session_id']`). Flask/werkzeug expects cookie values to be strings, not bytes.

---

## **How to Fix**

### 1. **Force Session Values to be Strings**
In your `get_or_create_session()` function in `app.py`, make sure you always store a string, not bytes:

**Find this code:**
```python
if 'session_id' not in session:
    session['session_id'] = str(uuid.uuid4())
    # ... rest of code ...
```
**If you ever decode or encode session values, make sure you use `.decode()` or `.encode()` appropriately.**

### 2. **Patch: Always Store as String**
To be extra safe, you can update the assignment to:
```python
session['session_id'] = str(session['session_id']) if isinstance(session.get('session_id'), bytes) else session.get('session_id', str(uuid.uuid4()))
```
But the original code should already store a string, so check if anywhere else you are putting a bytes value in the session.

---

## **Quick Diagnostic**
- Add a debug print right after setting the session:
  ```python
  print("session_id type:", type(session['session_id']))
  ```
- Restart your app and try the `/chat` endpoint again. If you see `<class 'bytes'>`, something is storing bytes instead of a string.

---

## **Summary**
- The error is caused by storing a bytes object in the session.
- Make sure all session values (especially `session['session_id']`) are always strings.

Would you like me to provide a code patch for your `app.py` to ensure this?