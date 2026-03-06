"""
Enhanced AI Service with Real-Time Safety Intelligence
Chatbot powered by Google Gemini + comprehensive local safety knowledge engine.
Works even WITHOUT API key using Tamil Nadu-specific safety data.
"""

import os
import re
import time
import random
import base64
from datetime import datetime
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Load environment variables - check multiple locations
for env_path in [
    os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'),
    os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env'),
    '.env',
]:
    if os.path.exists(env_path):
        load_dotenv(dotenv_path=env_path)
        print(f"[AI SERVICE] Loaded .env from: {env_path}")
        break

# ─── Gemini Configuration ───────────────────────────────────────────
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
GEMINI_MODEL_NAME = 'gemini-2.5-flash'
model = None

# Retry configuration for production reliability
MAX_RETRIES = 3
RETRY_BASE_DELAY = 1.0  # seconds, doubles each retry
MAX_HISTORY_MESSAGES = 10  # Keep last N messages for context
GEMINI_TIMEOUT = 30  # seconds

try:
    if GEMINI_API_KEY:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel(GEMINI_MODEL_NAME)
        print(f"[AI SERVICE] [OK] Gemini model loaded: {GEMINI_MODEL_NAME}")
    else:
        print("[AI SERVICE] [WARN] GEMINI_API_KEY not found - using local safety engine")
except Exception as e:
    print(f"[AI SERVICE] [WARN] Gemini init error: {e} - falling back to local safety engine")

# Conversation history for multi-turn chat (in-memory cache, populated from DB)
conversation_histories = {}


def load_conversation_from_db(conversation_id: str) -> List[Dict]:
    """Load recent conversation history from PostgreSQL for context."""
    try:
        from database.db import get_db_connection, close_connection
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT message, sender
            FROM chat_messages
            WHERE conversation_id = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (conversation_id, MAX_HISTORY_MESSAGES),
        )
        rows = cursor.fetchall()
        close_connection(conn)
        # Reverse to chronological order
        return [{'role': row['sender'], 'text': row['message']} for row in reversed(rows)]
    except Exception as e:
        print(f"[AI] DB history load error: {e}")
        return []

# ─── Tamil Nadu Safety Knowledge Base ────────────────────────────────
# Reference data for local fallback — Gemini handles all places in real-time

TN_AREAS = {
    't nagar': {
        'coords': (13.0417, 80.2338),
        'safety_level': 'moderate',
        'crowd_peak': '5 PM - 9 PM',
        'crowd_off': 'Before 10 AM',
        'safe_hours': '8 AM - 8 PM',
        'risky_hours': 'After 10 PM',
        'notes': 'T Nagar is Chennai\'s busiest shopping district. Ranganathan Street gets extremely crowded (15,000+ people) during evenings and weekends. Pickpocketing risk is HIGH during peak hours. Well-lit main roads but avoid narrow side lanes after dark.',
        'tips': [
            'Keep bags in front, not on shoulder — snatch thefts reported on Ranganathan Street',
            'Use Panagal Park area as a safe meeting point',
            'T Nagar Police Station is on South Usman Road (100m from bus stand)',
            'Auto-rickshaws overcharge heavily here — use Ola/Uber',
            'Best shopping hours: 10 AM - 1 PM (less crowded)',
        ],
        'landmarks': 'Pondy Bazaar, Ranganathan Street, Panagal Park',
        'police_contact': '+91-44-24341550',
    },
    'egmore': {
        'coords': (13.0732, 80.2609),
        'safety_level': 'moderate',
        'crowd_peak': '6 PM - 10 PM',
        'safe_hours': '6 AM - 9 PM',
        'risky_hours': 'After 11 PM (near railway station)',
        'notes': 'Egmore is a mixed area — the railway station zone has good police presence but attracts touts. The National Museum area is safe. Hotels near the station are budget-friendly but verify safety first.',
        'tips': [
            'Egmore Railway Station has a women\'s help desk and CCTV coverage',
            'Avoid walking alone in the railway colony area after dark',
            'The Government Museum complex is very safe during opening hours',
            'Use prepaid auto stands near the station instead of haggling',
        ],
        'police_contact': '+91-44-28192255',
    },
    'mylapore': {
        'coords': (13.0339, 80.2619),
        'safety_level': 'safe',
        'crowd_peak': '6 PM - 8 PM (temple area)',
        'safe_hours': '5 AM - 10 PM',
        'risky_hours': 'After 11 PM (residential, quiet)',
        'notes': 'Mylapore is one of Chennai\'s safest and most cultural neighborhoods. The Kapaleeshwarar Temple area is well-lit and busy. The tank area and Luz Corner have good police patrolling. Great for solo female travelers.',
        'tips': [
            'San Thome Cathedral beach area is well-patrolled',
            'Chitrakulam Street has excellent food and is safe',
            'The area around Mylapore tank is well-lit until 10 PM',
            'R.K. Mutt Road is very safe for evening walks',
        ],
        'police_contact': '+91-44-24951555',
    },
    'adyar': {
        'coords': (13.0067, 80.2575),
        'safety_level': 'safe',
        'safe_hours': '6 AM - 10 PM',
        'risky_hours': 'After 11 PM',
        'notes': 'Adyar is a residential and academic area (IIT Madras, Adyar Cancer Institute). Generally very safe. Well-lit main roads. The Adyar Eco Park and river area can be isolated after dark.',
        'tips': [
            'IIT Madras campus area is extremely safe',
            'Adyar Lattice Bridge Road is well-lit',
            'Avoid the river bank area after dark',
            'Good police response — Adyar station is responsive',
        ],
        'police_contact': '+91-44-24421320',
    },
    'anna nagar': {
        'coords': (13.0850, 80.2101),
        'safety_level': 'safe',
        'safe_hours': '6 AM - 10 PM',
        'notes': 'Anna Nagar is one of Chennai\'s safest localities. Well-planned, wide roads, good lighting. The Tower Park area has joggers until late evening. Very family-friendly.',
        'tips': [
            'Anna Nagar Tower Park is safe for evening walks',
            'Second Avenue and Third Avenue are well-lit commercial strips',
            'Multiple hospitals (SIMS, Apollo) make it very safe',
        ],
        'police_contact': '+91-44-26212525',
    },
    'chennai': {
        'coords': (13.0827, 80.2707),
        'safety_level': 'moderate',
        'notes': 'Chennai is generally safe for women travelers compared to other metros. Safe areas: Adyar, Mylapore, Anna Nagar, Besant Nagar. Moderate caution: T Nagar, Egmore. Extra caution after dark: Central Station area, Broadway. MRTS and Metro are safe and modern.',
        'tips': [
            'Chennai Metro is very safe — has dedicated women\'s coaches',
            'Use app-based cabs (Ola/Uber) especially after 9 PM',
            'Beach areas (Marina, Besant Nagar) are safe until 8 PM',
            'Most restaurants and shops close by 11 PM',
            'Emergency: Call 100 (Police) or 1091 (Women Helpline)',
        ],
        'police_contact': '100',
    },
    'coimbatore': {
        'coords': (11.0168, 76.9558),
        'safety_level': 'safe',
        'notes': 'Coimbatore is considered one of the safest cities in Tamil Nadu. Clean, well-maintained infrastructure. R.S. Puram and Race Course areas are very safe. The bus stand area can be crowded. Great for solo women travelers.',
        'tips': [
            'R.S. Puram is the safest area for accommodation',
            'Coimbatore has excellent bus and train connectivity',
            'Fun Republic Mall area is well-lit and safe',
            'Avoid isolated areas near Singanallur lake after dark',
        ],
        'police_contact': '+91-422-2300170',
    },
    'madurai': {
        'coords': (9.9252, 78.1198),
        'safety_level': 'moderate',
        'notes': 'Madurai is a temple city centered around Meenakshi Temple. The temple area is generally safe with strong police presence. The streets around the temple can be crowded and disorienting. Night markets near the temple are busy until late.',
        'tips': [
            'Meenakshi Temple area has good police presence and CCTV',
            'Stay near K.K. Nagar or Anna Nagar for safer accommodation',
            'Avoid areas near the Vaigai River after dark',
            'Madurai Junction station has 24/7 women\'s help desk',
        ],
        'police_contact': '+91-452-2531212',
    },
    'ooty': {
        'coords': (11.4102, 76.6950),
        'safety_level': 'safe',
        'crowd_peak': 'April-June (tourist season)',
        'notes': 'Ooty is generally very safe. Tourist police are active during season. The lake area, Botanical Garden, and main market are well-lit. Isolated plantation roads should be avoided at night. Book the toy train in advance.',
        'tips': [
            'Ooty lake area is well-patrolled by tourist police',
            'Hotels near Commercial Road are safest bet',
            'Avoid unmarked taxis — use hotel transport',
            'Carry warm clothes even in summer (gets cold at night)',
            'The toy train from Mettupalayam is very safe and scenic',
        ],
        'police_contact': '+91-423-2444033',
    },
    'kodaikanal': {
        'coords': (10.2381, 77.4892),
        'safety_level': 'safe',
        'notes': 'Kodaikanal is a peaceful hill station. The lake area is safe and busy. Coaker\'s Walk, Bryant Park are tourist-friendly. Some roads to waterfalls are isolated — go in groups. Well-connected main area.',
        'tips': [
            'Kodaikanal Lake and surrounding roads are safe',
            'Bicycle rental from shops near the lake is safe',
            'Pillar Rocks viewpoint road can be isolated — go in daylight',
            'Fresh chocolate shops near lake are genuine',
        ],
        'police_contact': '+91-4542-241500',
    },
    'pondicherry': {
        'coords': (11.9416, 79.8083),
        'safety_level': 'safe',
        'notes': 'Pondicherry is very safe for women travelers. The French Quarter (White Town) is well-maintained and tourist-friendly. Rock Beach promenade is safe until late. The Auroville area requires separate transport.',
        'tips': [
            'White Town / French Quarter is extremely safe',
            'Rock Beach promenade is safe until 10 PM',
            'Rent bicycles from Mission Street area',
            'Auroville is safe but isolated — arrange return transport',
        ],
        'police_contact': '+91-413-2339068',
    },
    'kanyakumari': {
        'coords': (8.0883, 77.5385),
        'safety_level': 'safe',
        'notes': 'Kanyakumari is a popular tourist spot. Very safe during the day. The Vivekananda Rock Memorial area is well-organized. Beach area has police patrolling. Hotels near the temple are budget-friendly and safe.',
        'tips': [
            'Book ferry to Vivekananda Rock early (long queues by 10 AM)',
            'Sunset Point is crowded but safe',
            'Hotels near Kumari Amman Temple are safest',
        ],
        'police_contact': '+91-4652-246800',
    },
    'rameswaram': {
        'coords': (9.2876, 79.3129),
        'safety_level': 'safe',
        'notes': 'Rameswaram is a peaceful pilgrimage town. The temple area is very safe. Beaches can be deserted after dark. Dhanushkodi road requires a jeep. Very tourist-friendly locals.',
        'tips': [
            'Temple area is safe 24/7 with CCTV',
            'Avoid unofficial guides demanding fees',
            'Book jeep to Dhanushkodi from official stand',
            'Pamban Bridge area has great views but be careful of wind',
        ],
        'police_contact': '+91-4573-221223',
    },
    'mahabalipuram': {
        'coords': (12.6269, 80.1927),
        'safety_level': 'safe',
        'notes': 'Mahabalipuram is a UNESCO heritage site, very tourist-friendly. Safe beach area with tourist police. Several backpacker hostels. Good restaurants along the beach road.',
        'tips': [
            'Shore Temple area is safe and well-maintained by ASI',
            'Beach area has tourist police present during the day',
            'Tiger Cave is a bit isolated — visit in groups',
            'ECR (highway) has good lighting and rest stops',
        ],
        'police_contact': '+91-44-27422275',
    },
}

# Common place name aliases — maps alternate names to canonical TN_AREAS keys
PLACE_ALIASES = {
    'marina': 'marina beach',
    'marina beach': 'marina beach',
    'elliot': 'besant nagar',
    'elliots beach': 'besant nagar',
    "elliot's beach": 'besant nagar',
    'besant nagar': 'besant nagar',
    'besant nagar beach': 'besant nagar',
    'pondy': 'pondicherry',
    'puducherry': 'pondicherry',
    'trichy': 'trichy',
    'tiruchirappalli': 'trichy',
    'tanjore': 'thanjavur',
    'thanjavur': 'thanjavur',
    'mamallapuram': 'mahabalipuram',
    'kovalam': 'kovalam',
    'velankanni': 'velankanni',
    'chidambaram': 'chidambaram',
    'rameshwaram': 'rameswaram',
}

# Time-based safety analysis
def get_time_safety(hour: int) -> str:
    if 6 <= hour < 10:
        return "early_morning"
    elif 10 <= hour < 16:
        return "daytime"
    elif 16 <= hour < 19:
        return "evening"
    elif 19 <= hour < 22:
        return "night"
    else:
        return "late_night"


SYSTEM_PROMPT = """You are 'SafeHer Assistant', a highly advanced AI safety companion for women traveling in Tamil Nadu, India.
Current Time: {current_time}

Your core responsibilities:
1. PREVENTIVE SAFETY — Analyze if a location is safe to visit at the current time. Consider crowd density, lighting, police presence, and crime trends.
2. REAL-TIME AWARENESS — Use the nearby police stations and hospital data provided to give actionable advice.
3. EMPATHY — Be warm, supportive, and empowering. Never dismiss user concerns.
4. Include SPECIFIC details: nearby police station names, distances, phone numbers.
5. Give TIME-SPECIFIC advice (different for 2 PM vs 10 PM).
6. For emergencies: ALWAYS mention 100 (Police), 112 (National Emergency), 1091 (Women Helpline).

IMPORTANT RULES:
- You can answer about ANY place in Tamil Nadu or India — you are not limited to a fixed list.
- If the user asks about a place, provide detailed safety info, crowd info, best times to visit, and nearby landmarks.
- If the user asks about weather, provide seasonal weather patterns for that area.
- If the user asks multiple questions in one message, answer ALL of them naturally.
- Be conversational and natural — don't give rigid/robotic 2-line answers.
- Give comprehensive, detailed answers that cover multiple aspects of the user's query.
- If the user mentions being alone at a place, give specific safety tips for being alone there.

CRITICAL FORMATTING RULES — FOLLOW STRICTLY:
- NEVER use markdown formatting such as **bold**, *italic*, ## headers, ### subheadings, or bullet points with *.
- NEVER use asterisks (*) for any purpose — no *, **, or *** anywhere in your response.
- Use plain text only. Use emojis for emphasis instead of bold/italic formatting.
- Use line breaks and numbered lists (1. 2. 3.) to structure your response.
- Use bullet points with • (bullet character) or - (dash), NEVER with *.
- Keep the tone warm, professional, and easy to read on a mobile screen.

REAL-TIME SAFETY DATA FOR THIS CONVERSATION:
{safety_context}

AREA KNOWLEDGE:
{area_knowledge}

RESPOND as a caring, knowledgeable safety companion. Be specific, actionable, and reassuring.
Use emojis sparingly but effectively. Structure your response clearly with plain text only.
"""


def clean_response(text: str) -> str:
    """Strip markdown formatting from AI responses for clean mobile display."""
    import re
    # Remove bold markers **text** or __text__
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'__(.+?)__', r'\1', text)
    # Remove italic markers *text* or _text_ (single)
    text = re.sub(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', r'\1', text)
    # Remove header markers ## or ###
    text = re.sub(r'^#{1,4}\s*', '', text, flags=re.MULTILINE)
    # Replace markdown bullet * with •
    text = re.sub(r'^\* ', '• ', text, flags=re.MULTILINE)
    # Clean up any remaining stray asterisks used as bullets
    text = re.sub(r'^\*\s+', '• ', text, flags=re.MULTILINE)
    return text.strip()


def get_real_time_context(user_location: Optional[Dict] = None, place_name: Optional[str] = None) -> str:
    """Fetch real-time data from OSM to provide context."""
    try:
        from services.mapillary_service import search_pois_overpass

        context_parts = []
        lat, lng = None, None

        # Try to resolve place name to coordinates
        if place_name:
            for area_key, area_data in TN_AREAS.items():
                if area_key in place_name.lower():
                    lat, lng = area_data['coords']
                    break

        if not lat and user_location:
            lat = user_location.get('lat')
            lng = user_location.get('lng')

        if not lat:
            return "Location not available. Providing general Tamil Nadu safety advice."

        # Get live data from OSM
        police = search_pois_overpass(lat, lng, 'police', 10000)
        hospitals = search_pois_overpass(lat, lng, 'hospital', 10000)

        total_emergency = len(police) + len(hospitals)
        if total_emergency == 0:
            context_parts.append("⚠ WARNING: No police stations or hospitals found within 10km. This area is ISOLATED.")
        elif total_emergency < 5:
            context_parts.append(f"⚠ Limited emergency services: {len(police)} police, {len(hospitals)} hospitals within 10km.")
        else:
            context_parts.append(f"✅ Good coverage: {len(police)} police stations, {len(hospitals)} hospitals within 10km.")

        if police:
            context_parts.append("\nNearest Police Stations:")
            for p in police[:3]:
                phone = p.get('phone', 'N/A')
                context_parts.append(f"  • {p['name']} — {p['distance_km']}km, Phone: {phone}")

        if hospitals:
            context_parts.append("\nNearest Hospitals:")
            for h in hospitals[:3]:
                phone = h.get('phone', 'N/A')
                context_parts.append(f"  • {h['name']} — {h['distance_km']}km, Phone: {phone}")

        return "\n".join(context_parts)
    except Exception as e:
        print(f"[AI] Context fetch error: {e}")
        return "Live safety data temporarily unavailable."


def get_area_knowledge(place_name: Optional[str] = None) -> str:
    """Get area-specific safety knowledge from local database."""
    if not place_name:
        return "No specific area mentioned."

    for area_key, data in TN_AREAS.items():
        if area_key in place_name.lower():
            parts = [f"📍 Area: {area_key.title()}"]
            parts.append(f"Safety Level: {data.get('safety_level', 'unknown').upper()}")
            if data.get('notes'):
                parts.append(f"Overview: {data['notes']}")
            if data.get('safe_hours'):
                parts.append(f"Safe Hours: {data['safe_hours']}")
            if data.get('risky_hours'):
                parts.append(f"Risky Hours: {data['risky_hours']}")
            if data.get('crowd_peak'):
                parts.append(f"Peak Crowd: {data['crowd_peak']}")
            if data.get('tips'):
                parts.append("Safety Tips:")
                for tip in data['tips']:
                    parts.append(f"  • {tip}")
            if data.get('police_contact'):
                parts.append(f"Local Police: {data['police_contact']}")
            return "\n".join(parts)

    # Even if not in TN_AREAS, return what we can — don't block Gemini
    return f"Area '{place_name}' — no pre-cached safety data. Use real-time analysis."


def extract_place_from_message(message: str) -> Optional[str]:
    """Extract place name from user message — handles aliases and multi-word names."""
    msg_lower = message.lower()

    # Check aliases first (longest match first to handle "marina beach" before "marina")
    sorted_aliases = sorted(PLACE_ALIASES.keys(), key=len, reverse=True)
    for alias in sorted_aliases:
        if alias in msg_lower:
            return PLACE_ALIASES[alias]

    # Check direct TN_AREAS keys (longest match first)
    sorted_keys = sorted(TN_AREAS.keys(), key=len, reverse=True)
    for area_key in sorted_keys:
        if area_key in msg_lower:
            return area_key

    # Try to extract any proper noun / place-like word not in common English
    # This catches places NOT in our database — Gemini will handle them
    common_words = {
        'safe', 'now', 'tell', 'about', 'weather', 'how', 'is', 'it', 'the',
        'can', 'you', 'please', 'what', 'where', 'when', 'alone', 'visit',
        'go', 'going', 'want', 'also', 'and', 'beach', 'temple', 'park',
        'station', 'hotel', 'near', 'help', 'me', 'there', 'here', 'good',
        'bad', 'morning', 'evening', 'night', 'today', 'tomorrow', 'right',
        'should', 'will', 'would', 'could', 'have', 'has', 'had', 'been',
        'are', 'was', 'were', 'for', 'with', 'from', 'this', 'that', 'at',
        'in', 'on', 'to', 'of', 'a', 'an', 'the', 'my', 'i', 'we', 'they',
        'time', 'place', 'area', 'city', 'town', 'food', 'eat', 'travel',
        'police', 'hospital', 'bus', 'train', 'auto', 'taxi', 'cab',
    }
    # Extract capitalized words or phrases that might be place names
    words = re.findall(r'[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*', message)
    for word in words:
        if word.lower() not in common_words and len(word) > 2:
            return word.lower()

    return None


def get_ai_response(user_message: str, conversation_id: str,
                    user_location: Optional[Dict] = None,
                    image_data: Optional[str] = None,
                    voice_data: Optional[str] = None) -> str:
    """Get AI response — uses Gemini if available, otherwise comprehensive local engine.
    
    Key architecture decisions:
    - System prompt is injected ONLY on the first message of a conversation (saves ~80% tokens)
    - Conversation history is loaded from DB, not in-memory (survives server restarts)
    - Images are sent as proper Gemini multipart content
    - Exponential backoff with jitter for rate limit resilience
    """
    try:
        place_name = extract_place_from_message(user_message)
        current_time = datetime.now().strftime("%I:%M %p, %A")
        current_hour = datetime.now().hour

        # Get context
        safety_context = get_real_time_context(user_location, place_name)
        area_knowledge = get_area_knowledge(place_name)

        # Handle voice-only messages
        if voice_data and not user_message.strip():
            user_message = "[Voice message received — please provide safety guidance]"

        # Try Gemini first — with retry logic for production reliability
        if model:
            last_error = None
            for attempt in range(1, MAX_RETRIES + 1):
                try:
                    # Load conversation history from DB for context
                    db_history = load_conversation_from_db(conversation_id)
                    is_first_message = len(db_history) <= 1  # 0 or just the current user msg

                    # Build or reuse chat session
                    if conversation_id not in conversation_histories:
                        # Rebuild chat from DB history for continuity
                        gemini_history = []
                        for msg in db_history[:-1]:  # Exclude current message (not yet answered)
                            role = 'user' if msg['role'] == 'user' else 'model'
                            gemini_history.append({'role': role, 'parts': [msg['text']]})
                        conversation_histories[conversation_id] = model.start_chat(history=gemini_history)

                    chat = conversation_histories[conversation_id]

                    # Build content parts — system prompt ONLY on first message
                    if is_first_message:
                        prompt = SYSTEM_PROMPT.format(
                            current_time=current_time,
                            safety_context=safety_context,
                            area_knowledge=area_knowledge,
                        )
                        text_content = f"{prompt}\n\nUser: {user_message}"
                    else:
                        # Subsequent messages: just send user text + minimal context refresh
                        text_content = user_message
                        # Add location context only if relevant
                        if place_name or user_location:
                            text_content += f"\n\n[Context: Time={current_time}. {safety_context[:200]}]"

                    content_parts = [text_content]

                    # Proper multipart image handling for Gemini
                    if image_data:
                        try:
                            # Decode and re-encode to ensure valid base64
                            image_bytes = base64.b64decode(image_data)
                            content_parts.append({
                                "mime_type": "image/jpeg",
                                "data": base64.b64encode(image_bytes).decode('utf-8')
                            })
                            content_parts[0] = f"[User attached a photo for safety analysis] {content_parts[0]}"
                        except Exception as img_err:
                            print(f"[AI] Image processing error: {img_err}")
                            content_parts[0] = f"[User tried to attach a photo but it couldn't be processed] {content_parts[0]}"

                    if voice_data:
                        content_parts[0] = f"[Voice message from user] {content_parts[0]}"

                    response = chat.send_message(content_parts)
                    print(f"[AI] Gemini 2.5 Flash responded successfully (attempt {attempt})")
                    return clean_response(response.text)

                except Exception as e:
                    last_error = str(e)
                    is_transient = any(code in last_error for code in ["429", "503", "500", "UNAVAILABLE", "RESOURCE_EXHAUSTED"])
                    is_transient = is_transient or "quota" in last_error.lower() or "rate" in last_error.lower()

                    if is_transient and attempt < MAX_RETRIES:
                        # Exponential backoff with jitter
                        delay = RETRY_BASE_DELAY * (2 ** (attempt - 1)) + random.uniform(0, 1)
                        print(f"[AI] Gemini transient error (attempt {attempt}/{MAX_RETRIES}): {last_error[:100]}")
                        print(f"[AI] Retrying in {delay:.1f}s...")
                        time.sleep(delay)
                        # Reset chat session on retry (stale session can cause issues)
                        conversation_histories.pop(conversation_id, None)
                        continue
                    else:
                        print(f"[AI] Gemini failed (attempt {attempt}/{MAX_RETRIES}): {last_error[:200]}")
                        break

            print(f"[AI] All {MAX_RETRIES} Gemini attempts exhausted — falling back to local engine")

        # Local Safety Intelligence Engine 
        return clean_response(get_intelligent_local_response(user_message, place_name, current_hour,
                                               safety_context, area_knowledge, user_location))

    except Exception as e:
        print(f"[AI] Critical error: {e}")
        return clean_response("I'm having a technical issue, but your safety is my priority.\n\n"
                "🚨 Emergency Numbers:\n"
                "• Police: 100\n"
                "• National Emergency: 112\n"
                "• Women Helpline: 1091\n\n"
                "Please call if you feel unsafe. Use the SOS button for immediate help.")


def get_intelligent_local_response(message: str, place_name: Optional[str],
                                     hour: int, safety_context: str,
                                     area_knowledge: str,
                                     user_location: Optional[Dict] = None) -> str:
    """Comprehensive local safety engine — works without any API key.
    Handles ANY place, not just hardcoded ones. Provides natural, multi-topic responses."""
    msg_lower = message.lower()
    time_period = get_time_safety(hour)
    current_time = datetime.now().strftime("%I:%M %p")
    response_parts = []

    # ── EMERGENCY detection ──
    emergency_words = ['attack', 'following', 'danger', 'help me', 'scared', 'stalking',
                       'harass', 'groping', 'threatened', 'kidnap', 'robbery']
    if any(w in msg_lower for w in emergency_words):
        response = ("🚨 **EMERGENCY RESPONSE**\n\n"
                     "I hear you and I'm taking this seriously. Here's what to do RIGHT NOW:\n\n"
                     "1️⃣ **Call 100** (Police) or **112** (National Emergency) immediately\n"
                     "2️⃣ **Move** to the nearest crowded, well-lit area\n"
                     "3️⃣ **Press the SOS button** in this app to alert your emergency contacts\n"
                     "4️⃣ **Women Helpline: 1091** (24/7)\n\n")
        if safety_context and "Police" in safety_context:
            response += f"📍 **Nearby help:**\n{safety_context}\n\n"
        response += "Stay on the line with emergency services. You are NOT alone. 💪"
        return response

    # ── GREETING ──
    greetings = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening', 'good night']
    if any(msg_lower.strip() == g or msg_lower.strip().startswith(g + ' ') or msg_lower.strip().startswith(g + '!') for g in greetings):
        if not place_name:  # Pure greeting, no place mentioned
            time_greeting = {
                'early_morning': 'Good morning',
                'daytime': 'Good afternoon',
                'evening': 'Good evening',
                'night': 'Good evening',
                'late_night': 'Hello'
            }.get(time_period, 'Hello')

            response = f"{time_greeting}! 🙏 Welcome to SafeHer.\n\n"
            response += "I'm your personal safety companion for Tamil Nadu. Here's how I can help:\n\n"
            response += "🔍 **\"Is Marina Beach safe right now?\"** — I'll give you real-time safety assessment\n"
            response += "🚨 **\"I feel unsafe\"** — Immediate emergency guidance\n"
            response += "📍 **\"Nearest police station\"** — Real-time locations with phone numbers\n"
            response += "🏨 **\"Safe hotels near me\"** — Safety-vetted accommodation\n"
            response += "🗺️ **\"Tips for visiting Ooty\"** — Area-specific travel advice\n"
            response += "🌤️ **\"Weather in Chennai\"** — Current weather & travel advice\n\n"
            response += "Just ask me anything about traveling safely in Tamil Nadu! 💜"
            return response

    # ── Detect multiple topics in the message ──
    has_weather_query = any(w in msg_lower for w in ['weather', 'rain', 'hot', 'cold', 'climate', 'temperature', 'humid', 'sun', 'monsoon'])
    has_safety_query = any(w in msg_lower for w in ['safe', 'danger', 'risk', 'alone', 'solo', 'visit', 'go to', 'travel', 'how is', 'is it', 'tell', 'about', 'info', 'now'])
    has_alone_concern = any(w in msg_lower for w in ['alone', 'solo', 'single', 'by myself', 'lonely', 'no one'])
    has_crowd_query = any(w in msg_lower for w in ['crowd', 'busy', 'rush', 'packed', 'crowded', 'empty', 'deserted'])
    has_police_query = any(w in msg_lower for w in ['police', 'station', 'hospital', 'ambulance', 'emergency number'])
    has_hotel_query = any(w in msg_lower for w in ['hotel', 'stay', 'accommodation', 'lodge', 'where to stay'])
    has_transport_query = any(w in msg_lower for w in ['bus', 'train', 'auto', 'cab', 'taxi', 'transport', 'uber', 'ola', 'metro'])
    has_food_query = any(w in msg_lower for w in ['food', 'eat', 'restaurant', 'biryani', 'idli', 'dosa', 'coffee', 'snack'])
    has_general_tips = any(w in msg_lower for w in ['tip', 'advice', 'suggestion', 'recommend', 'precaution'])

    # ── PLACE-SPECIFIC response — works for ANY place ──
    if place_name:
        area = TN_AREAS.get(place_name, {})
        is_known_place = bool(area)
        place_title = place_name.title()

        # Build a comprehensive response covering all asked topics
        response_parts.append(f"📍 **{place_title}**")
        response_parts.append(f"🕐 Current time: {current_time}\n")

        # Safety / general info about the place
        if is_known_place:
            safety_level = area.get('safety_level', 'unknown')

            # Time-specific safety
            if time_period == 'late_night':
                risky = area.get('risky_hours', 'After 10 PM')
                response_parts.append(f"⚠️ **Late Night Advisory:** It's currently late night. This falls in the risky hours ({risky}) for {place_title}.")
                if safety_level == 'safe':
                    response_parts.append("\nEven though this area is generally safe, I'd recommend:")
                    response_parts.append("• Travel by Ola/Uber (not auto-rickshaws)")
                    response_parts.append("• Share your live location with someone you trust")
                    response_parts.append("• Stay on main, well-lit roads\n")
                else:
                    response_parts.append("\n**I'd advise against visiting right now.** Wait until morning.\n")
            elif time_period == 'night':
                response_parts.append(f"🌙 **Evening Advisory for {place_title}:**")
                if safety_level in ['safe', 'moderate']:
                    response_parts.append("The area is reasonably safe at this hour but becoming less busy.")
                    response_parts.append("• Stick to main roads and commercial areas")
                    response_parts.append("• Use app-based transport (Ola/Uber)\n")
            elif time_period in ['daytime', 'early_morning']:
                safe_text = 'very safe' if safety_level == 'safe' else 'safe with normal precautions'
                response_parts.append(f"✅ **{place_title} is {safe_text} at this time.**\n")
            elif time_period == 'evening':
                peak = area.get('crowd_peak', 'evening hours')
                response_parts.append(f"⚡ This is typically the peak crowd period ({peak}).")
                if 'crowd' in str(area.get('notes', '')).lower():
                    response_parts.append("Expect high foot traffic — keep belongings close.\n")

            # Area notes
            if area.get('notes'):
                response_parts.append(f"\nℹ️ **About {place_title}:** {area['notes']}\n")

            # Alone concern
            if has_alone_concern:
                response_parts.append(f"👤 **Being Alone at {place_title}:**")
                if time_period in ['late_night', 'night']:
                    response_parts.append("⚠️ I'd strongly recommend NOT being alone here at this hour.")
                    response_parts.append("• If you must be here, stay on the main well-lit roads")
                    response_parts.append("• Keep your phone charged and share live location")
                    response_parts.append("• Have emergency numbers ready: 100 (Police), 112 (Emergency)")
                elif safety_level == 'safe':
                    response_parts.append("This area is generally safe for solo travelers during the day.")
                    response_parts.append("• Stay aware of your surroundings")
                    response_parts.append("• Share your location with a trusted contact")
                else:
                    response_parts.append("Exercise caution when alone here.")
                    response_parts.append("• Stick to crowded, well-lit areas")
                    response_parts.append("• Keep your phone accessible at all times")
                response_parts.append("")

            # Tips
            if area.get('tips'):
                response_parts.append("🛡️ **Safety Tips:**")
                for tip in area['tips']:
                    response_parts.append(f"  • {tip}")
                response_parts.append("")

        else:
            # Place NOT in our database — give general but helpful response
            response_parts.append(f"ℹ️ **About {place_title}:**")
            response_parts.append(f"I don't have detailed pre-loaded data for {place_title}, but here's what I can tell you:\n")

            if time_period in ['late_night', 'night']:
                response_parts.append(f"⚠️ **Night Advisory:** It's currently {current_time}. Regardless of the area:")
                response_parts.append("• Stay on well-lit, main roads")
                response_parts.append("• Use Ola/Uber instead of auto-rickshaws")
                response_parts.append("• Share your live location with a trusted contact")
                response_parts.append("• Keep emergency numbers handy: 100 (Police), 112 (Emergency)\n")
            else:
                response_parts.append(f"✅ Daytime travel is generally safer. Here are general tips:")
                response_parts.append("• Stay in populated, well-lit areas")
                response_parts.append("• Keep belongings close in crowded places")
                response_parts.append("• Use verified transport services\n")

            if has_alone_concern:
                response_parts.append(f"👤 **Being Alone:** Take extra precautions when alone:")
                response_parts.append("• Share your live location with someone you trust")
                response_parts.append("• Note landmarks and nearest police stations")
                response_parts.append("• Keep your phone charged\n")

        # Weather info (for any place)
        if has_weather_query:
            response_parts.append(f"🌤️ **Weather in {place_title}:**")
            month = datetime.now().month
            if month in [4, 5, 6]:
                response_parts.append("☀️ It's **summer season** in Tamil Nadu right now.")
                response_parts.append("• Temperatures can reach 38-42°C — stay hydrated")
                response_parts.append("• Carry water, sunscreen, and a hat")
                response_parts.append("• Best to avoid outdoor activities between 11 AM - 3 PM")
                if 'beach' in place_name.lower():
                    response_parts.append("• Beach visits are best during early morning or after 4 PM")
            elif month in [7, 8, 9]:
                response_parts.append("🌦️ It's the **pre-monsoon / southwest monsoon** period.")
                response_parts.append("• Expect occasional showers — carry an umbrella")
                response_parts.append("• Humidity is high — wear light, breathable clothes")
            elif month in [10, 11, 12]:
                response_parts.append("🌧️ It's **northeast monsoon / winter** season.")
                response_parts.append("• Heavy rains possible — check weather alerts before traveling")
                response_parts.append("• Flooding can occur in low-lying areas — stay cautious")
                if 'beach' in place_name.lower():
                    response_parts.append("• ⚠️ Sea can be rough during monsoon — avoid going near the water")
                    response_parts.append("• Beach promenades may be slippery")
            else:  # Jan, Feb, Mar
                response_parts.append("✅ It's the **pleasant season** — great time to visit!")
                response_parts.append("• Temperatures are comfortable (22-30°C)")
                response_parts.append("• Perfect for sightseeing and outdoor activities")
            response_parts.append("")

        # Nearby emergency services
        if safety_context and "Police" in safety_context:
            response_parts.append(f"🚔 **Nearby Emergency Services:**\n{safety_context}\n")
        elif is_known_place and area.get('police_contact'):
            response_parts.append(f"📞 Local Police: **{area['police_contact']}**\n")

        response_parts.append("Stay safe! 💜 Ask me anything else about your travel.")
        return "\n".join(response_parts)

    # ── POLICE/HOSPITAL query (no place) ──
    if has_police_query:
        response = "🚔 **Emergency Services:**\n\n"
        response += "• **Police:** 100\n"
        response += "• **National Emergency:** 112\n"
        response += "• **Women Helpline:** 1091\n"
        response += "• **Ambulance:** 108\n"
        response += "• **Fire:** 101\n\n"

        if safety_context and "Police" in safety_context:
            response += f"📍 **Nearest to you:**\n{safety_context}\n\n"

        response += "Tap the **Safety** tab to see all nearby stations with direct call buttons."
        return response

    # ── HOTEL/ACCOMMODATION query (no place) ──
    if has_hotel_query:
        response = "🏨 **Safe Accommodation Tips for Tamil Nadu:**\n\n"
        response += "**General tips:**\n"
        response += "  • Choose hotels near main roads with 24/7 reception\n"
        response += "  • Check for CCTV and security at the entrance\n"
        response += "  • Read reviews from solo female travelers\n"
        response += "  • Verify the lock, peephole, and emergency exits on arrival\n"
        response += "  • Prefer well-known chains or verified OYO/Treebo properties\n\n"
        response += "Check the **Hotels** tab for safety-vetted options nearby! 🛡️"
        return response

    # ── TRANSPORT query ──
    if has_transport_query:
        response = "🚗 **Transport Safety in Tamil Nadu:**\n\n"
        response += "✅ **Safest options:**\n"
        response += "  • Ola/Uber (GPS tracked, driver ID visible)\n"
        response += "  • Chennai Metro (has women's coach)\n"
        response += "  • TNSTC government buses\n\n"
        response += "⚠️ **Use caution with:**\n"
        response += "  • Auto-rickshaws (agree on fare BEFORE boarding)\n"
        response += "  • Share autos after dark\n"
        response += "  • Unmarked private vehicles\n\n"
        response += "💡 **Tips:**\n"
        response += "  • Share trip details with a trusted contact\n"
        response += "  • Sit behind the driver, not beside\n"
        response += "  • Note the vehicle number before boarding\n"
        return response

    # ── FOOD query ──
    if has_food_query:
        response = "🍛 **Food Safety Tips for Tamil Nadu:**\n\n"
        response += "Tamil Nadu has incredible food! Here are some tips:\n\n"
        response += "  • Eat at busy restaurants (high turnover = fresh food)\n"
        response += "  • Try filter coffee at local shops — it's safe and amazing ☕\n"
        response += "  • Avoid street food in very isolated areas\n"
        response += "  • Drink bottled water, not tap water\n"
        response += "  • Popular safe chains: Saravana Bhavan, Murugan Idli, Sangeetha\n\n"
        response += "**Must-try dishes:** Idli, Dosa, Chettinad Chicken, Filter Coffee, Jigarthanda (Madurai special)\n\n"
        response += "Check the **Community** tab for food recommendations! 🍽️"
        return response

    # ── WEATHER query (no place) ──
    if has_weather_query:
        month = datetime.now().month
        response = "🌤️ **Weather in Tamil Nadu:**\n\n"
        if month in [4, 5, 6]:
            response += "☀️ It's **summer** — temperatures can reach 38-42°C.\n"
            response += "• Stay hydrated, carry water and sunscreen\n"
            response += "• Avoid outdoor activities 11 AM - 3 PM\n"
            response += "• Hill stations (Ooty, Kodaikanal) are cooler alternatives\n"
        elif month in [7, 8, 9]:
            response += "🌦️ **Pre-monsoon / Southwest monsoon** period.\n"
            response += "• Occasional showers — carry an umbrella\n"
            response += "• Western Tamil Nadu gets more rain\n"
        elif month in [10, 11, 12]:
            response += "🌧️ **Northeast monsoon** — heavy rains possible.\n"
            response += "• Check weather alerts before traveling\n"
            response += "• Flooding is possible in Chennai, low-lying coastal areas\n"
            response += "• Beaches may have rough seas\n"
        else:
            response += "✅ **Pleasant season** — ideal for traveling!\n"
            response += "• Comfortable temperatures (22-30°C)\n"
            response += "• Great time for sightseeing\n"
        response += "\nAsk me about weather for a specific place for more details! 📍"
        return response

    # ── GENERAL safety tips ──
    if has_general_tips:
        response = "🛡️ **General Safety Tips for Tamil Nadu:**\n\n"
        response += "1️⃣ Share live location with trusted contacts\n"
        response += "2️⃣ Keep phone charged (carry power bank)\n"
        response += "3️⃣ Save emergency numbers: 100, 112, 1091\n"
        response += "4️⃣ Use app-based transport after dark\n"
        response += "5️⃣ Stay in well-lit, populated areas\n"
        response += "6️⃣ Trust your instincts — if it feels wrong, leave\n"
        response += "7️⃣ Keep copies of ID (don't carry originals)\n"
        response += "8️⃣ Inform hotel reception about your plans\n\n"
        response += "For area-specific tips, ask me about any location! 📍"
        return response

    # ── SMART FALLBACK — still try to be helpful ──
    response = f"I'm SafeHer AI 💜 It's {current_time} right now.\n\n"
    response += "I'd love to help you! Here are some things you can ask me:\n\n"
    response += "🔍 **\"Is Marina Beach safe right now?\"** — Safety assessment for any place\n"
    response += "🌤️ **\"Weather in Ooty\"** — Weather and travel conditions\n"
    response += "👤 **\"Going alone to T Nagar\"** — Solo travel safety tips\n"
    response += "🚨 **\"I feel unsafe\"** — Immediate emergency guidance\n"
    response += "📍 **\"Nearest police station\"** — Real-time locations\n"
    response += "🏨 **\"Hotels in Pondicherry\"** — Safe accommodation\n"
    response += "🚗 **\"Safe transport options\"** — Transport safety\n"
    response += "🍛 **\"Where to eat safely\"** — Food recommendations\n\n"

    if safety_context and "Police" in safety_context:
        response += f"📍 **Your nearby resources:**\n{safety_context}\n\n"

    response += "Just ask me anything about traveling safely in Tamil Nadu! 💜"
    return response


def analyze_safety_threat(message: str) -> Dict:
    """Quick threat level analysis."""
    message_lower = message.lower()
    high_words = ['attack', 'following', 'stalking', 'danger', 'kidnap', 'groping', 'threatened']
    medium_words = ['unsafe', 'scared', 'worried', 'uncomfortable', 'alone', 'dark']

    if any(word in message_lower for word in high_words):
        return {'threat_level': 'high', 'recommended_actions': ['call_police', 'activate_sos', 'share_location']}
    elif any(word in message_lower for word in medium_words):
        return {'threat_level': 'medium', 'recommended_actions': ['stay_alert', 'share_location', 'move_to_public']}
    return {'threat_level': 'low', 'recommended_actions': ['stay_alert']}


if __name__ == '__main__':
    # Test the local engine
    print("=== Testing SafeHer AI ===\n")
    print(get_ai_response("Is T Nagar safe to visit right now?", "test_1"))
    print("\n" + "="*50 + "\n")
    print(get_ai_response("marina beach alone now?? also tell about weather now?", "test_2"))
    print("\n" + "="*50 + "\n")
    print(get_ai_response("I'm being followed", "test_3"))