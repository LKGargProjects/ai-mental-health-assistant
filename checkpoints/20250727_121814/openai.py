import os
from openai import OpenAI

def get_openai_response(message, mode='mental_health'):
    """Get response from OpenAI API"""
    try:
        client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        
        system_message = """You are a supportive AI assistant for high school students. 
        Respond with empathy and understanding. If the user seems distressed, 
        provide emotional support and suggest healthy coping strategies. 
        Keep responses concise and focused."""

        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": message}
            ],
            max_tokens=150,
            temperature=0.7,
        )

        return response.choices[0].message.content

    except Exception as e:
        print(f"OpenAI API error: {str(e)}")
        return "I'm having trouble connecting to my AI services. Please try again in a moment."
