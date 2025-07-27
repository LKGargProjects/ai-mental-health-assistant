import os
import google.generativeai as genai
from typing import Dict, List
from datetime import datetime, timedelta

# Store conversations with timestamp for cleanup
conversations: Dict[str, List[dict]] = {}
CONVERSATION_TIMEOUT = timedelta(hours=1)  # Clear conversations older than 1 hour

def cleanup_old_conversations():
    """Remove conversations that are older than the timeout"""
    current_time = datetime.now()
    to_remove = []
    for session_id in conversations:
        if conversations[session_id]:
            last_message_time = conversations[session_id][-1].get('timestamp')
            if last_message_time and current_time - last_message_time > CONVERSATION_TIMEOUT:
                to_remove.append(session_id)
    
    for session_id in to_remove:
        del conversations[session_id]

def get_gemini_response(message, mode='mental_health', session_id=None):
    """Get response from Gemini API with conversation history"""
    try:
        api_key = os.getenv('GEMINI_API_KEY')
        if not api_key:
            print("Gemini API key not found")
            return "Configuration error: Gemini API key not found"

        # Configure the API
        genai.configure(api_key=api_key)
        
        # Create the model
        try:
#            model = genai.GenerativeModel('models/gemini-1.5-flash-latest')
            model = genai.GenerativeModel('models/gemini-2.5-flash-lite')
        except Exception as e:
            print(f"Error creating Gemini model: {str(e)}")
            return f"Error initializing AI model: {str(e)}"
        
        # Initialize or get conversation history
        if session_id not in conversations:
            conversations[session_id] = []
        
        # Clean up old conversations periodically
        cleanup_old_conversations()
        
        # Prepare the conversation history
        history = conversations[session_id]
        
        # Prepare the prompt with context
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        # Build the conversation context
        conversation_context = ""
        if history:
            conversation_context = "\n".join([
                f"{'User' if msg['is_user'] else 'Assistant'}: {msg['content']}"
                for msg in history[-5:]  # Keep last 5 messages for context
            ])
            conversation_context = f"\nPrevious conversation:\n{conversation_context}\n"

        prompt = f"{system_message}\n{conversation_context}\nUser: {message}"
        
        # Generate response
        try:
            response = model.generate_content(prompt)
            if not response or not response.text:
                print("Empty response from Gemini")
                return "I received an empty response. Please try again."
            
            # Store the conversation
            history.append({
                'content': message,
                'is_user': True,
                'timestamp': datetime.now()
            })
            history.append({
                'content': response.text,
                'is_user': False,
                'timestamp': datetime.now()
            })
            conversations[session_id] = history
            
            return response.text
        except Exception as e:
            print(f"Error generating content: {str(e)}")
            return f"Error generating response: {str(e)}"

    except Exception as e:
        print(f"Unexpected Gemini API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
