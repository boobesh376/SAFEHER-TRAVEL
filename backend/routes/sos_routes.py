"""
SOS Emergency Routes
JWT-protected. Stores alerts in Supabase PostgreSQL.
10-second per-user cooldown to prevent spam.
"""

import logging
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from database.db import get_db_connection, close_connection
from services.notification_service import send_sms, generate_whatsapp_links
from services.police_service import alert_nearest_police

logger = logging.getLogger(__name__)
sos_bp = Blueprint('sos', __name__)

# Per-user cooldown tracker: { user_id: last_trigger_datetime }
_last_sos_time: dict = {}
_COOLDOWN_SECONDS = 10


# ─── Trigger SOS ──────────────────────────────────────────────────────────────

@sos_bp.route('/trigger', methods=['POST'])
@jwt_required()
def trigger_sos():
    """
    POST /api/sos/trigger
    Header: Authorization: Bearer <access_token>
    Body: { "latitude": float, "longitude": float }
    Returns: { success, sos_id, whatsapp_links, police_stations, message }
    """
    conn = None
    try:
        user_id = get_jwt_identity()

        # ── Cooldown check ─────────────────────────────────────────────────────
        now = datetime.utcnow()
        last = _last_sos_time.get(user_id)
        if last:
            elapsed = (now - last).total_seconds()
            if elapsed < _COOLDOWN_SECONDS:
                remaining = int(_COOLDOWN_SECONDS - elapsed)
                return jsonify({
                    'success': False,
                    'error': f'Please wait {remaining} seconds before triggering SOS again.',
                }), 429

        data = request.get_json(force=True) or {}
        latitude  = data.get('latitude')
        longitude = data.get('longitude')

        if latitude is None or longitude is None:
            return jsonify({'success': False, 'error': 'latitude and longitude are required'}), 400

        try:
            latitude  = float(latitude)
            longitude = float(longitude)
        except (ValueError, TypeError):
            return jsonify({'success': False, 'error': 'Invalid coordinates'}), 400

        location = {'lat': latitude, 'lng': longitude}

        # ── Fetch user + emergency contacts from DB ────────────────────────────
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT name FROM users WHERE id = %s", (user_id,))
        user_row = cursor.fetchone()
        user_name = user_row['name'] if user_row else 'SafeHer User'

        cursor.execute(
            "SELECT contact_phone FROM emergency_contacts WHERE user_id = %s",
            (user_id,),
        )
        emergency_contacts = [row['contact_phone'] for row in cursor.fetchall()]

        # ── Alert police stations ──────────────────────────────────────────────
        police_stations = alert_nearest_police(location, limit=5)

        map_link = f"https://maps.google.com/?q={latitude},{longitude}"

        # SMS police stations
        for station in police_stations:
            msg = (
                f"EMERGENCY SOS: {user_name} needs help at {latitude},{longitude}. "
                f"Distance: {station.get('distance_km')}km. ETA: {station.get('eta_minutes')}min."
            )
            try:
                send_sms(station.get('phone', ''), msg)
            except Exception:
                pass  # Non-critical

        # SMS emergency contacts
        for contact in emergency_contacts:
            msg = (
                f"EMERGENCY ALERT from SafeHer! {user_name} has activated SOS and needs immediate help! "
                f"Location: {map_link} — Police: 100 | Emergency: 112 | Women Helpline: 1091"
            )
            try:
                send_sms(contact, msg)
            except Exception:
                pass

        # WhatsApp links for Flutter to open
        whatsapp_links = generate_whatsapp_links(emergency_contacts, user_name, location)

        # ── Save to PostgreSQL ─────────────────────────────────────────────────
        sos_id = str(uuid.uuid4())
        cursor.execute(
            """
            INSERT INTO sos_alerts (id, user_id, latitude, longitude, status, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (sos_id, user_id, latitude, longitude, 'triggered', datetime.utcnow()),
        )
        conn.commit()

        # Record last trigger time for cooldown
        _last_sos_time[user_id] = now

        logger.info("SOS triggered by user %s at (%s, %s)", user_id, latitude, longitude)

        primary_police = police_stations[0] if police_stations else {}

        return jsonify({
            'success': True,
            'sos_id': sos_id,
            'message': (
                f"SOS activated. Alerted {len(police_stations)} police station(s) "
                f"and {len(emergency_contacts)} emergency contact(s)."
            ),
            'police_station': primary_police,
            'all_police_stations': police_stations,
            'whatsapp_links': whatsapp_links,
            'eta_minutes': primary_police.get('eta_minutes', 5),
            'status': 'triggered',
        }), 200

    except Exception as e:
        logger.error("SOS trigger error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'SOS activation failed. Please try again.'}), 500
    finally:
        close_connection(conn)


def send_sms_with_retry(phone, message, max_attempts=3):
    """Send SMS with retry logic for reliability."""
    import time
    for attempt in range(1, max_attempts + 1):
        try:
            result = send_sms(phone, message)
            if result:
                return True
        except Exception as e:
            logger.warning("SMS attempt %d/%d failed for %s: %s", attempt, max_attempts, phone, e)
        if attempt < max_attempts:
            time.sleep(1.5 * attempt)  # 1.5s, 3s backoff
    return False


# ─── Update Live Location (called every 30s from client) ──────────────────────

@sos_bp.route('/update-location/<sos_id>', methods=['POST'])
@jwt_required()
def update_sos_location(sos_id):
    """
    POST /api/sos/update-location/<sos_id>
    Header: Authorization: Bearer <access_token>
    Body: { "latitude": float, "longitude": float }
    Updates the SOS alert with the latest GPS coordinates.
    """
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}

        latitude = data.get('latitude')
        longitude = data.get('longitude')

        if latitude is None or longitude is None:
            return jsonify({'success': False, 'error': 'Coordinates required'}), 400

        try:
            latitude = float(latitude)
            longitude = float(longitude)
        except (ValueError, TypeError):
            return jsonify({'success': False, 'error': 'Invalid coordinates'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        # Update the SOS alert with new location
        cursor.execute(
            """
            UPDATE sos_alerts
            SET latitude = %s, longitude = %s
            WHERE id = %s AND user_id = %s AND status = 'triggered'
            """,
            (latitude, longitude, sos_id, user_id),
        )
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'success': False, 'error': 'Active SOS alert not found'}), 404

        logger.info("SOS location updated for %s: (%s, %s)", sos_id, latitude, longitude)

        return jsonify({
            'success': True,
            'message': 'Location updated',
            'latitude': latitude,
            'longitude': longitude,
        }), 200

    except Exception as e:
        logger.error("SOS location update error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Location update failed'}), 500
    finally:
        close_connection(conn)


# ─── Deactivate SOS ───────────────────────────────────────────────────────────

@sos_bp.route('/deactivate/<sos_id>', methods=['POST'])
@jwt_required()
def deactivate_sos(sos_id):
    """POST /api/sos/deactivate/<sos_id> — marks alert as resolved"""
    conn = None
    try:
        user_id = get_jwt_identity()
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "UPDATE sos_alerts SET status = 'resolved', resolved_at = %s WHERE id = %s AND user_id = %s",
            (datetime.utcnow(), sos_id, user_id),
        )
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'success': False, 'error': 'SOS alert not found'}), 404

        return jsonify({'success': True, 'message': 'SOS deactivated. Stay safe!'}), 200

    except Exception as e:
        logger.error("SOS deactivate error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Deactivation failed'}), 500
    finally:
        close_connection(conn)


# ─── SOS History ──────────────────────────────────────────────────────────────

@sos_bp.route('/history', methods=['GET'])
@jwt_required()
def get_sos_history():
    """GET /api/sos/history — returns last 20 SOS alerts for current user"""
    conn = None
    try:
        user_id = get_jwt_identity()
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT id, latitude, longitude, status, created_at, resolved_at
            FROM sos_alerts
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT 20
            """,
            (user_id,),
        )
        alerts = cursor.fetchall()

        return jsonify({
            'success': True,
            'alerts': [
                {**dict(a), 'created_at': str(a['created_at']), 'resolved_at': str(a['resolved_at'])}
                for a in alerts
            ],
        }), 200

    except Exception as e:
        logger.error("SOS history error: %s", e)
        return jsonify({'success': False, 'error': 'Could not fetch SOS history'}), 500
    finally:
        close_connection(conn)