import os
from openai import OpenAI

def _debug_enabled() -> bool:
    return (os.getenv('AI_DEBUG_LOGS') or '').lower() == 'true'

def _debug(*args):
    if _debug_enabled():
        print('[openai]', *args)

def get_openai_response(message, mode='mental_health'):
    """Get response from OpenAI API"""
    try:
        api_key = os.getenv('OPENAI_API_KEY')
        if not (api_key or '').strip():
            print("OpenAI API key not found")
            return "Configuration error: OpenAI API key not found"

        client = OpenAI(api_key=api_key)
        model_name = "gpt-3.5-turbo"
        temperature = 0.7
        max_tokens = 150
        _debug(f"invoke model={model_name} temp={temperature} max_tokens={max_tokens} msg_len={len(message or '')}")
        
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        response = client.chat.completions.create(
            model=model_name,
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": message}
            ],
            max_tokens=max_tokens,
            temperature=temperature,
        )

        content = response.choices[0].message.content
        try:
            usage = getattr(response, 'usage', None)
            if usage:
                _debug(f"success prompt_tokens={getattr(usage, 'prompt_tokens', None)} completion_tokens={getattr(usage, 'completion_tokens', None)} total_tokens={getattr(usage, 'total_tokens', None)}")
            else:
                _debug("success no_usage")
        except Exception:
            pass
        return content

    except Exception as e:
        _debug(f"error {e}")
        print(f"OpenAI API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."

