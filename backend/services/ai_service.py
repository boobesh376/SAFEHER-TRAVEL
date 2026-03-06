"""
AI Service
Chatbot powered by Google Gemini API
"""

import os
import google.generativeai as genai

# Configure Gemini
genai.configure(api_key=os.getenv('GEMINI_API_KEY'))

# Create the model
model = genai.GenerativeModel('gemini-2.5-flash')

# Conversation history storage (use Redis in production)
conversation_histories = {}

SYSTEM_PROMPT = """You are a safety assistant for Safe Her Travel, an app designed to help women travelers in Tamil Nadu, India stay safe. Your role is to:

1. Provide immediate safety advice and guidance
2. Help users assess potentially dangerous situations
3. Guide them to nearby police stations, hospitals, or safe zones
4. Offer emotional support during distressing situations
5. Provide information about women's safety resources in Tamil Nadu

Key Guidelines:
- Be empathetic, supportive, and non-judgmental
- Prioritize user safety above all else
- If someone is in immediate danger, advise them to call emergency services (100 for police, 112 for emergency)
- Provide practical, actionable advice
- Be aware of cultural context in Tamil Nadu
- Never dismiss or minimize safety concerns

Emergency numbers to remember:
- Police: 100
- Ambulance: 108
- National Emergency: 112
- Women Helpline: 1091
- Child Helpline: 1098

Stay calm, be supportive, and help keep users safe."""

def get_ai_response(user_message, conversation_id):
    """
    Get AI response using Gemini API
    """
    try:
        # Initialize conversation history if needed
        if conversation_id not in conversation_histories:
            conversation_histories[conversation_id] = model.start_chat(history=[])
        
        chat = conversation_histories[conversation_id]
        
        # Add system context to first message
        if len(chat.history) == 0:
            full_message = f"{SYSTEM_PROMPT}\n\nUser: {user_message}"
        else:
            full_message = user_message
        
        # Send message and get response
        response = chat.send_message(full_message)
        
        return response.text
        
    except Exception as e:
        print(f"AI Service Error: {e}")
        # Fallback responses for common queries
        return get_fallback_response(user_message)

def get_fallback_response(message):
    """Provide fallback responses if AI service is unavailable"""
    message_lower = message.lower()
    
    if any(word in message_lower for word in ['danger', 'unsafe', 'scared', 'help', 'emergency']):
        return """I'm here to help. If you're in immediate danger:
        
1. Call 100 for police or 112 for national emergency
2. Move to a well-lit, populated area if possible
3. Share your location with trusted contacts
4. Use the SOS button in the app

Can you tell me more about your situation so I can help better?"""
    
    elif any(word in message_lower for word in ['police', 'station', 'cop']):
        return """I can help you find the nearest police station. Please share your current location, and I'll provide you with:
- Nearest police stations
- Their contact numbers
- Directions to reach them

In emergency, dial 100 for immediate police assistance."""
    
    elif any(word in message_lower for word in ['hospital', 'medical', 'doctor', 'ambulance']):
        return """For medical emergencies:
- Call 108 for ambulance
- I can help locate nearest hospitals

Share your location, and I'll find nearby medical facilities for you."""
    
    else:
        return """Hello! I'm here to help keep you safe. I can assist with:

- Emergency guidance
- Finding nearby police stations and hospitals
- Safety tips for traveling in Tamil Nadu
- Emotional support during distress

How can I help you today?"""

def clear_conversation(conversation_id):
    """Clear conversation history"""
    if conversation_id in conversation_histories:
        del conversation_histories[conversation_id]