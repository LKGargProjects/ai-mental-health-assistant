import os
import requests

def _debug_enabled() -> bool:
    return (os.getenv('AI_DEBUG_LOGS') or '').lower() == 'true'

def _debug(*args):
    if _debug_enabled():
        print('[perplexity]', *args)

def get_perplexity_response(message, mode='mental_health'):
    """Get response from Perplexity API"""
    try:
        api_key = (os.getenv('PERPLEXITY_API_KEY') or '').strip()
        if not api_key:
            alt = (os.getenv('PPLX_API_KEY') or '').strip()
            if alt:
                api_key = alt
                _debug('using_alias_key=PPLX_API_KEY')
        if not api_key:
            print("Perplexity API key not found")
            return "Configuration error: Perplexity API key not found"
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
        }
        
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        model_name = 'mistral-7b-instruct'
        data = {
            'model': model_name,
            'messages': [
                {'role': 'system', 'content': system_message},
                {'role': 'user', 'content': message}
            ]
        }

        endpoint = 'https://api.perplexity.ai/chat/completions'
        _debug(f"invoke model={model_name} endpoint={endpoint} msg_len={len(message or '')}")

        response = requests.post(endpoint, headers=headers, json=data)
        
        if response.status_code == 200:
            try:
                j = response.json()
                content = j['choices'][0]['message']['content']
                _debug('success')
                return content
            except Exception as je:
                _debug(f"parse_error {je}")
                raise
        else:
            print(f"Perplexity API error: {response.status_code} - {response.text}")
            return "I'm having trouble connecting to my AI services. Please try again in a moment."

    except Exception as e:
        _debug(f"error {e}")
        print(f"Perplexity API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."

