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

def get_gemini_response(message, mode='mental_health', session_id=None, risk_level=None):
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
        
        # For crisis-related messages, clear history to avoid AI learning crisis resources
        crisis_keywords = ['die', 'suicide', 'kill myself', 'end my life', 'take my life', 'want to die']
        is_crisis_message = any(keyword in message.lower() for keyword in crisis_keywords)
        
        if is_crisis_message:
            # Clear history for crisis messages to prevent AI from learning crisis resources
            history = []
            conversations[session_id] = []
        else:
            # Prepare the conversation history
            history = conversations[session_id]
        
        # Prepare the prompt with context based on risk level
        if risk_level == 'crisis':
            system_message = """You are a supportive AI assistant for high school students. 
            The user is in crisis and needs immediate emotional support.
            Respond with empathy, understanding, and emotional support ONLY.
            Do NOT mention any crisis resources, helpline numbers, or specific actions.
            Focus on emotional support and being present with the user.
            Crisis resources will be provided separately by the system."""
        else:
            system_message = """You are a supportive AI assistant for high school students. 
            Respond with empathy and understanding. If the user seems distressed, 
            provide emotional support and suggest healthy coping strategies. 
            Keep responses concise and focused.
            
            ABSOLUTE RULE: You must NEVER mention any crisis helpline numbers, phone numbers, or specific resources.
            Examples of what NOT to mention: 988, 111, 741741, "National Suicide Prevention Lifeline", "Crisis Text Line", etc.
            Crisis resources will be provided separately by the system.
            Focus ONLY on emotional support, understanding, and general guidance.
            If you mention any crisis resources, you are violating this rule."""

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
            
            # For crisis messages, completely replace the AI response
            if risk_level == 'crisis':
                cleaned_response = """I hear how much pain you're in, and it takes incredible strength to express these feelings. Please know that you're not alone, and there are people who want to help you through this difficult time.

Your feelings are valid, and it's okay to not be okay. You don't have to carry this burden alone. There are people who care about you and want to support you.

Please remember that these intense feelings can pass, and there is hope for things to get better. You deserve support and care."""
            else:
                # For non-crisis messages, use the AI response as-is
                cleaned_response = response.text
            
            # Clean up extra whitespace and formatting
            import re
            cleaned_response = re.sub(r'\n\s*\n\s*\n', '\n\n', cleaned_response)  # Remove extra blank lines
            cleaned_response = cleaned_response.strip()
            
            # Store the conversation
            history.append({
                'content': message,
                'is_user': True,
                'timestamp': datetime.now()
            })
            history.append({
                'content': cleaned_response,
                'is_user': False,
                'timestamp': datetime.now()
            })
            conversations[session_id] = history
            
            return cleaned_response
        except Exception as e:
            print(f"Error generating content: {str(e)}")
            return f"Error generating response: {str(e)}"

    except Exception as e:
        print(f"Unexpected Gemini API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
