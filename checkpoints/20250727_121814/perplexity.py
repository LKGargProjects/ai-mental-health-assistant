import os
import requests

def get_perplexity_response(message, mode='mental_health'):
    """Get response from Perplexity API"""
    try:
        api_key = os.getenv('PERPLEXITY_API_KEY')
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
        }
        
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        data = {
            'model': 'mistral-7b-instruct',
            'messages': [
                {'role': 'system', 'content': system_message},
                {'role': 'user', 'content': message}
            ]
        }

        response = requests.post(
            'https://api.perplexity.ai/chat/completions',
            headers=headers,
            json=data
        )
        
        if response.status_code == 200:
            return response.json()['choices'][0]['message']['content']
        else:
            print(f"Perplexity API error: {response.status_code} - {response.text}")
            return "I'm having trouble connecting to my AI services. Please try again in a moment."

    except Exception as e:
        print(f"Perplexity API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
