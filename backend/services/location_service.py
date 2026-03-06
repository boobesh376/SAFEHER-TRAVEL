"""
Location Service
Distance calculation and location-based utilities
"""

import math

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Calculate distance between two coordinates using Haversine formula
    
    Args:
        lat1, lon1: First coordinate
        lat2, lon2: Second coordinate
    
    Returns:
        float: Distance in kilometers
    """
    # Earth radius in kilometers
    R = 6371.0
    
    # Convert to radians
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    # Differences
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    # Haversine formula
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    distance = R * c
    return distance

def get_nearest_locations(user_lat, user_lon, locations, limit=10):
    """
    Get nearest locations sorted by distance
    
    Args:
        user_lat, user_lon: User's coordinates
        locations: List of location dictionaries with 'latitude' and 'longitude'
        limit: Maximum number of results
    
    Returns:
        list: Sorted locations with distance
    """
    locations_with_distance = []
    
    for location in locations:
        distance = calculate_distance(
            user_lat, user_lon,
            location['latitude'], location['longitude']
        )
        
        location_copy = location.copy()
        location_copy['distance_km'] = round(distance, 2)
        locations_with_distance.append(location_copy)
    
    # Sort by distance
    locations_with_distance.sort(key=lambda x: x['distance_km'])
    
    return locations_with_distance[:limit]

def is_within_radius(lat1, lon1, lat2, lon2, radius_km):
    """
    Check if a location is within specified radius
    
    Args:
        lat1, lon1: First coordinate
        lat2, lon2: Second coordinate
        radius_km: Radius in kilometers
    
    Returns:
        bool: True if within radius
    """
    distance = calculate_distance(lat1, lon1, lat2, lon2)
    return distance <= radius_km

def get_location_bounds(lat, lon, radius_km):
    """
    Get bounding box for a location and radius
    
    Args:
        lat, lon: Center coordinates
        radius_km: Radius in kilometers
    
    Returns:
        dict: Bounding box with min/max lat/lon
    """
    # Approximate degrees per km (varies by latitude)
    lat_km = 110.574
    lon_km = 111.320 * math.cos(math.radians(lat))
    
    lat_delta = radius_km / lat_km
    lon_delta = radius_km / lon_km
    
    return {
        'min_lat': lat - lat_delta,
        'max_lat': lat + lat_delta,
        'min_lon': lon - lon_delta,
        'max_lon': lon + lon_delta
    }

def estimate_travel_time(distance_km, mode='driving'):
    """
    Estimate travel time based on distance and mode
    
    Args:
        distance_km: Distance in kilometers
        mode: Transport mode (driving, walking, transit)
    
    Returns:
        int: Estimated time in minutes
    """
    # Average speeds in km/h
    speeds = {
        'driving': 40,
        'walking': 5,
        'transit': 25,
        'bicycle': 15
    }
    
    speed = speeds.get(mode, 40)
    time_hours = distance_km / speed
    time_minutes = int(time_hours * 60)
    
    return time_minutes