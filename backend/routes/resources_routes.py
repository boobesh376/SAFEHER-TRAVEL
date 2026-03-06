"""
Resources Routes - Stable OSM + SQLite Fallback
Startup-ready nearby discovery with real phone numbers
"""

from flask import Blueprint, request, jsonify
from services.mapillary_service import search_pois_overpass, haversine, get_tn_phone_fallback
from database.db import get_db_connection, close_connection

resources_bp = Blueprint('resources', __name__)


# Whitelist of allowed table names to prevent SQL injection
_ALLOWED_TABLES = {'police_stations', 'hospitals', 'safe_zones'}


def get_db_resources(table, lat, lng, radius_km, amenity_type='police'):
    """Fetch resources from PostgreSQL database (fallback) with phone normalization."""
    if table not in _ALLOWED_TABLES:
        print(f"[DB ERROR] Invalid table name: {table}")
        return []

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Table name is safe — validated against whitelist above
        cursor.execute(f"SELECT * FROM {table}")
        rows = cursor.fetchall()

        results = []
        for row in rows:
            dist = haversine(lat, lng, row['latitude'], row['longitude'])
            if dist <= radius_km:
                d = dict(row)
                d['distance_km'] = round(dist, 2)
                d['lat'] = row['latitude']
                d['lng'] = row['longitude']
                d['source'] = 'Local Database'
                # Ensure phone is always present
                if not d.get('phone') and not d.get('emergency_phone'):
                    d['phone'] = get_tn_phone_fallback(
                        d.get('name', ''), d.get('address', ''), amenity_type
                    )
                elif d.get('emergency_phone') and not d.get('phone'):
                    d['phone'] = d['emergency_phone']
                results.append(d)

        return results

    except Exception as e:
        print(f"[DB ERROR] {e}")
        return []
    finally:
        close_connection(conn)


def merge_and_sort(primary_list, fallback_list):
    """Merge two lists and remove duplicates by name."""
    merged = {}

    def add_item(item):
        key = item.get("name", "").lower()
        if not key:
            return

        if key not in merged:
            merged[key] = item
        else:
            for k, v in item.items():
                if v and not merged[key].get(k):
                    merged[key][k] = v

    for item in primary_list:
        add_item(item)

    for item in fallback_list:
        add_item(item)

    final_list = list(merged.values())
    final_list.sort(key=lambda x: x.get("distance_km", 9999))

    return final_list


# ---------------- POLICE ---------------- #

@resources_bp.route('/police-stations', methods=['GET'])
def get_police_stations():
    try:
        lat = float(request.args.get('lat'))
        lng = float(request.args.get('lng'))

        # Default 10km radius for better coverage
        radius_m = int(request.args.get('radius', 10000))
        radius_km = radius_m / 1000

        print(f"[POLICE] Searching near {lat},{lng} ({radius_m}m)")

        # Primary: OSM with phone extraction
        osm_data = search_pois_overpass(lat, lng, 'police', radius_m)

        # Fallback: Local DB with phone normalization
        db_data = get_db_resources('police_stations', lat, lng, radius_km, 'police')

        final_list = merge_and_sort(osm_data, db_data)

        return jsonify({
            "success": True,
            "count": len(final_list),
            "stations": final_list,
            "radius_m": radius_m,
            "user_location": {"lat": lat, "lng": lng},
            "source": "OpenStreetMap + Local Fallback"
        }), 200

    except Exception as e:
        print(f"[POLICE ERROR] {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------- HOSPITAL ---------------- #

@resources_bp.route('/hospitals', methods=['GET'])
def get_hospitals():
    try:
        lat = float(request.args.get('lat'))
        lng = float(request.args.get('lng'))

        # Default 10km radius for better coverage
        radius_m = int(request.args.get('radius', 10000))
        radius_km = radius_m / 1000

        print(f"[HOSPITAL] Searching near {lat},{lng} ({radius_m}m)")

        osm_data = search_pois_overpass(lat, lng, 'hospital', radius_m)
        db_data = get_db_resources('hospitals', lat, lng, radius_km, 'hospital')

        final_list = merge_and_sort(osm_data, db_data)

        return jsonify({
            "success": True,
            "count": len(final_list),
            "hospitals": final_list,
            "radius_m": radius_m,
            "user_location": {"lat": lat, "lng": lng},
            "source": "OpenStreetMap + Local Fallback"
        }), 200

    except Exception as e:
        print(f"[HOSPITAL ERROR] {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------- EMERGENCY CONTACTS ---------------- #

@resources_bp.route('/emergency-contacts', methods=['GET'])
def get_emergency_contacts():
    return jsonify({
        "success": True,
        "contacts": {
            "police": "100",
            "national_emergency": "112",
            "ambulance": "108",
            "women_helpline": "1091",
            "fire": "101"
        }
    }), 200