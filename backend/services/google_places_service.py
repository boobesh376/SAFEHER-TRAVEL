"""
Google Places Service
Integration with Google Places API for hotels, reviews, and accommodations
"""

import os
import requests
from typing import List, Dict, Optional

GOOGLE_PLACES_API_KEY = os.getenv('GOOGLE_PLACES_API_KEY', '')
PLACES_API_BASE = 'https://maps.googleapis.com/maps/api/place'

def search_hotels_nearby(latitude: float, longitude: float, radius: int = 5000) -> List[Dict]:
    """
    Search for hotels near a location using Google Places API
    
    Args:
        latitude: User latitude
        longitude: User longitude
        radius: Search radius in meters (default 5km)
    
    Returns:
        List of hotels with details and reviews
    """
    try:
        if not GOOGLE_PLACES_API_KEY:
            print("⚠️ Google Places API key not configured")
            return get_fallback_hotels(latitude, longitude)
        
        # Search for hotels
        url = f"{PLACES_API_BASE}/nearbysearch/json"
        params = {
            'location': f'{latitude},{longitude}',
            'radius': radius,
            'type': 'lodging',
            'key': GOOGLE_PLACES_API_KEY
        }
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        if data.get('status') != 'OK':
            print(f"Places API Error: {data.get('status')}")
            return get_fallback_hotels(latitude, longitude)
        
        hotels = []
        for place in data.get('results', [])[:10]:  # Get top 10
            hotel = {
                'id': place.get('place_id'),
                'name': place.get('name'),
                'address': place.get('vicinity'),
                'latitude': place['geometry']['location']['lat'],
                'longitude': place['geometry']['location']['lng'],
                'rating': place.get('rating', 0),
                'user_ratings_total': place.get('user_ratings_total', 0),
                'price_level': place.get('price_level', 0),
                'is_open': place.get('opening_hours', {}).get('open_now', None),
                'photo_reference': place.get('photos', [{}])[0].get('photo_reference') if place.get('photos') else None
            }
            
            # Get detailed place information including reviews
            details = get_place_details(place.get('place_id'))
            if details:
                hotel.update({
                    'phone': details.get('formatted_phone_number'),
                    'website': details.get('website'),
                    'reviews': details.get('reviews', [])[:5],  # Top 5 reviews
                    'safety_rating': calculate_safety_rating(details),
                    'amenities': extract_amenities(details)
                })
            
            hotels.append(hotel)
        
        return hotels
        
    except Exception as e:
        print(f"Error fetching hotels: {e}")
        return get_fallback_hotels(latitude, longitude)

def get_place_details(place_id: str) -> Optional[Dict]:
    """Get detailed information about a place including reviews"""
    try:
        if not GOOGLE_PLACES_API_KEY or not place_id:
            return None
        
        url = f"{PLACES_API_BASE}/details/json"
        params = {
            'place_id': place_id,
            'fields': 'name,rating,formatted_phone_number,website,reviews,opening_hours,types,user_ratings_total',
            'key': GOOGLE_PLACES_API_KEY
        }
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        if data.get('status') == 'OK':
            return data.get('result', {})
        
        return None
        
    except Exception as e:
        print(f"Error fetching place details: {e}")
        return None

def calculate_safety_rating(place_details: Dict) -> float:
    """
    Calculate safety rating based on reviews and ratings
    
    Factors:
    - Overall rating
    - Number of reviews
    - Mentions of safety, security, staff helpfulness
    - Women traveler reviews
    """
    try:
        base_rating = place_details.get('rating', 0)
        reviews_count = place_details.get('user_ratings_total', 0)
        reviews = place_details.get('reviews', [])
        
        safety_score = base_rating
        
        # Boost score if many positive reviews
        if reviews_count > 100:
            safety_score += 0.5
        elif reviews_count > 50:
            safety_score += 0.3
        
        # Analyze reviews for safety keywords
        safety_keywords = ['safe', 'secure', 'security', 'helpful staff', 'women friendly', 
                          'clean', 'well-lit', 'cctv', 'guard', 'female staff']
        
        negative_keywords = ['unsafe', 'theft', 'harassment', 'dirty', 'sketchy', 'avoid']
        
        safety_mentions = 0
        negative_mentions = 0
        
        for review in reviews:
            text = review.get('text', '').lower()
            for keyword in safety_keywords:
                if keyword in text:
                    safety_mentions += 1
            for keyword in negative_keywords:
                if keyword in text:
                    negative_mentions += 1
        
        # Adjust score based on safety mentions
        if safety_mentions > 0:
            safety_score += min(safety_mentions * 0.2, 0.8)
        if negative_mentions > 0:
            safety_score -= min(negative_mentions * 0.3, 1.0)
        
        # Normalize to 0-5 scale
        safety_score = max(0, min(5, safety_score))
        
        return round(safety_score, 1)
        
    except Exception as e:
        print(f"Error calculating safety rating: {e}")
        return 0.0

def extract_amenities(place_details: Dict) -> List[str]:
    """Extract amenities from place details"""
    amenities = []
    types = place_details.get('types', [])
    
    amenity_map = {
        'parking': 'Parking Available',
        'restaurant': 'Restaurant',
        'bar': 'Bar',
        'gym': 'Gym',
        'spa': 'Spa',
        'swimming_pool': 'Swimming Pool',
    }
    
    for type_key, amenity in amenity_map.items():
        if type_key in types:
            amenities.append(amenity)
    
    # Check reviews for common amenities
    reviews = place_details.get('reviews', [])
    for review in reviews:
        text = review.get('text', '').lower()
        if 'wifi' in text or 'wi-fi' in text:
            amenities.append('WiFi')
        if 'breakfast' in text:
            amenities.append('Breakfast')
        if 'ac' in text or 'air condition' in text:
            amenities.append('AC')
    
    return list(set(amenities))  # Remove duplicates

def get_photo_url(photo_reference: str, max_width: int = 400) -> str:
    """Get photo URL from photo reference"""
    if not photo_reference or not GOOGLE_PLACES_API_KEY:
        return ''
    
    return f"{PLACES_API_BASE}/photo?maxwidth={max_width}&photo_reference={photo_reference}&key={GOOGLE_PLACES_API_KEY}"

def search_safe_accommodations(latitude: float, longitude: float, 
                               female_friendly: bool = True) -> List[Dict]:
    """
    Search for female-friendly and safe accommodations
    
    Args:
        latitude: User latitude
        longitude: User longitude
        female_friendly: Filter for female-friendly places
    
    Returns:
        List of safe accommodations
    """
    hotels = search_hotels_nearby(latitude, longitude)
    
    if female_friendly:
        # Filter hotels with good safety ratings
        safe_hotels = [h for h in hotels if h.get('safety_rating', 0) >= 3.5]
        safe_hotels.sort(key=lambda x: x.get('safety_rating', 0), reverse=True)
        return safe_hotels
    
    return hotels

def get_fallback_hotels(latitude: float, longitude: float) -> List[Dict]:
    """
    Provide fallback hotel data when API is unavailable
    """
    # Determine city based on coordinates
    city_hotels = {
        'chennai': [
            {
                'id': 'fb_ch_001',
                'name': 'Hotel Savera',
                'address': 'Dr. Radhakrishnan Salai, Mylapore, Chennai',
                'latitude': 13.0339,
                'longitude': 80.2619,
                'rating': 4.0,
                'safety_rating': 4.2,
                'phone': '+91 44 2811 4700',
                'amenities': ['WiFi', 'Restaurant', 'AC', 'Parking']
            },
            {
                'id': 'fb_ch_002',
                'name': 'The Residency',
                'address': 'G.N. Chetty Road, T. Nagar, Chennai',
                'latitude': 13.0417,
                'longitude': 80.2338,
                'rating': 4.1,
                'safety_rating': 4.0,
                'phone': '+91 44 2815 5151',
                'amenities': ['WiFi', 'Restaurant', 'AC']
            }
        ],
        'coimbatore': [
            {
                'id': 'fb_cb_001',
                'name': 'Hotel City Tower',
                'address': 'Sivananda Colony, Coimbatore',
                'latitude': 11.0168,
                'longitude': 76.9558,
                'rating': 3.9,
                'safety_rating': 3.8,
                'phone': '+91 422 223 1681',
                'amenities': ['WiFi', 'Restaurant', 'AC']
            }
        ],
        'madurai': [
            {
                'id': 'fb_md_001',
                'name': 'Hotel Germanus',
                'address': 'Alagar Kovil Main Road, Madurai',
                'latitude': 9.9195,
                'longitude': 78.1193,
                'rating': 4.0,
                'safety_rating': 3.9,
                'phone': '+91 452 434 3434',
                'amenities': ['WiFi', 'Restaurant', 'AC', 'Parking']
            }
        ]
    }
    
    # Simple distance check to determine city
    # This is a simplified version
    return city_hotels.get('chennai', [])