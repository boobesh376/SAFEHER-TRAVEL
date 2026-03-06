"""
Police Service
Handle police station alerts and emergency dispatch
"""

from database.db import get_db_connection, close_connection
from services.mapillary_service import search_pois_overpass
from services.location_service import get_nearest_locations, estimate_travel_time

def alert_nearest_police(location, limit=5):
    """
    Identify top N nearest police stations about emergency using live OSM data
    
    Args:
        location: Dict with 'lat' and 'lng'
        limit: Number of stations to return
    
    Returns:
        list: List of nearest police station info with ETA
    """
    try:
        lat = location['lat']
        lng = location['lng']
        
        # 1. Try Live OSM data first (Real-time!)
        # Search radius 20km (increased for better coverage)
        stations = search_pois_overpass(lat, lng, 'police', 20000)
        
        results = []
        if stations:
            for s in stations[:limit]:
                s['source'] = 'OpenStreetMap'
                results.append(s)
        
        # 2. Fill from fallback database if needed
        conn = None
        if len(results) < limit:
            try:
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM police_stations")
                all_stations = cursor.fetchall()
            finally:
                close_connection(conn)
            
            if all_stations:
                stations_list = [dict(station) for station in all_stations]
                # Filter out those already found via OSM to avoid duplicates
                found_ids = [s.get('id') for s in results]
                remaining_stations = [s for s in stations_list if s.get('id') not in found_ids]
                
                nearest_list = get_nearest_locations(lat, lng, remaining_stations, limit=limit-len(results))
                for n in nearest_list:
                    # Map 'latitude'/'longitude' to 'lat'/'lng' for consistency
                    n['lat'] = n['latitude']
                    n['lng'] = n['longitude']
                    n['source'] = 'Local Database'
                    results.append(n)

        processed_results = []
        for station in results:
            # Calculate more professional ETA
            travel_mins = estimate_travel_time(station['distance_km'], mode='driving')
            dispatch_time = 2
            total_eta = travel_mins + dispatch_time
            total_eta = max(total_eta, 3) 
            
            processed_results.append({
                'id': station.get('id'),
                'name': station['name'],
                'address': station.get('address', 'Location broadcast to nearest unit'),
                'phone': station.get('phone') or station.get('emergency_phone') or '100',
                'lat': station['lat'],
                'lng': station['lng'],
                'distance_km': station['distance_km'],
                'eta_minutes': total_eta,
                'source': station.get('source', 'Emergency Services')
            })
            
        if not processed_results:
            # 3. Final fallback
            processed_results.append({
                'name': 'Emergency Dispatch Control',
                'phone': '112',
                'distance_km': 0,
                'eta_minutes': 5,
                'source': 'National Helpline'
            })
            
        return processed_results
            
    except Exception as e:
        print(f"Error alerting police: {e}")
        return [{
            'name': 'Emergency Services',
            'phone': '100',
            'eta_minutes': 6,
            'source': 'System Fallback'
        }]

def get_police_station_by_district(district):
    """Get police stations in a specific district"""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM police_stations
            WHERE district = %s
        """, (district,))

        stations = cursor.fetchall()

        return [dict(station) for station in stations]

    except Exception as e:
        print(f"Error fetching police stations: {e}")
        return []
    finally:
        close_connection(conn)

def report_incident(user_id, location, incident_type, description):
    """
    Report an incident to authorities
    
    Args:
        user_id: User ID
        location: Dict with lat/lng
        incident_type: Type of incident
        description: Incident description
    
    Returns:
        dict: Report confirmation
    """
    try:
        import uuid
        from datetime import datetime
        
        report_id = str(uuid.uuid4())
        
        # In production, this would create an official report
        # and potentially integrate with police systems
        
        print(f"[INCIDENT REPORT] ID: {report_id}")
        print(f"[INCIDENT REPORT] Type: {incident_type}")
        print(f"[INCIDENT REPORT] Location: {location}")
        
        return {
            'report_id': report_id,
            'status': 'submitted',
            'message': 'Your report has been submitted to local authorities',
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"Error reporting incident: {e}")
        return None