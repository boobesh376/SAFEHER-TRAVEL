"""
Location Routes
Real-time location tracking and sharing
JWT-protected with Supabase PostgreSQL.
"""

import logging
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from database.db import get_db_connection, close_connection

logger = logging.getLogger(__name__)
location_bp = Blueprint('location', __name__)

# Store active location shares (in production, use Redis)
active_shares = {}


@location_bp.route('/update', methods=['POST'])
@jwt_required()
def update_location():
    """
    Update user's current location
    Request body: {
        "latitude": float,
        "longitude": float,
        "accuracy": float (optional)
    }
    """
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        accuracy = data.get('accuracy', 0)

        if latitude is None or longitude is None:
            return jsonify({'success': False, 'error': 'latitude and longitude are required'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO location_history (id, user_id, latitude, longitude, accuracy, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (str(uuid.uuid4()), user_id, latitude, longitude, accuracy, datetime.utcnow()))
        conn.commit()

        return jsonify({
            'success': True,
            'message': 'Location updated successfully',
            'timestamp': datetime.utcnow().isoformat()
        }), 200

    except Exception as e:
        logger.error("Location update error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        close_connection(conn)


@location_bp.route('/share', methods=['POST'])
@jwt_required()
def share_location():
    """
    Share live location with emergency contacts
    Request body: {
        "contacts": ["phone1", "phone2"],
        "duration_minutes": int (default 60)
    }
    """
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        contacts = data.get('contacts', [])
        duration = data.get('duration_minutes', 60)

        share_id = str(uuid.uuid4())

        active_shares[share_id] = {
            'user_id': user_id,
            'contacts': contacts,
            'started_at': datetime.utcnow().isoformat(),
            'duration_minutes': duration,
            'active': True
        }

        # Send sharing link to contacts via SMS
        from services.notification_service import send_sms
        share_link = f"https://safehertravel.com/track/{share_id}"

        for contact in contacts:
            msg = f"Location sharing activated. Track here: {share_link}"
            send_sms(contact, msg)

        return jsonify({
            'success': True,
            'share_id': share_id,
            'share_link': share_link,
            'expires_at': duration
        }), 200

    except Exception as e:
        logger.error("Location share error: %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500


@location_bp.route('/track/<share_id>', methods=['GET'])
def track_location(share_id):
    """Get shared location data"""
    conn = None
    try:
        if share_id not in active_shares:
            return jsonify({'success': False, 'error': 'Share not found or expired'}), 404

        share = active_shares[share_id]

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM location_history
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT 1
        """, (share['user_id'],))

        location = cursor.fetchone()

        return jsonify({
            'success': True,
            'location': dict(location) if location else None,
            'share_info': share
        }), 200

    except Exception as e:
        logger.error("Location track error: %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        close_connection(conn)


@location_bp.route('/history', methods=['GET'])
@jwt_required()
def get_location_history():
    """Get location history for the authenticated user"""
    conn = None
    try:
        user_id = get_jwt_identity()
        limit = min(int(request.args.get('limit', 100)), 500)

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM location_history
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT %s
        """, (user_id, limit))

        history = cursor.fetchall()

        return jsonify({
            'success': True,
            'history': [dict(loc) for loc in history]
        }), 200

    except Exception as e:
        logger.error("Location history error: %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        close_connection(conn)