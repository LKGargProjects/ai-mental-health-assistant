from dotenv import load_dotenv
import os

load_dotenv()
print("Gemini Key:", os.getenv("GEMINI_API_KEY"))
