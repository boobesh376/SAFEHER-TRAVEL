"""
Report Routes
Allows users to report incidents and suspicious activities.
JWT-protected. Uses Supabase PostgreSQL.
"""

import logging
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from database.db import get_db_connection, close_connection

logger = logging.getLogger(__name__)
report_bp = Blueprint('report', __name__)


@report_bp.route('/submit', methods=['POST'])
@jwt_required()
def submit_report():
    """
    Submit a safety report
    Request body: {
        "type": "string",
        "description": "string",
        "location": {"lat": float, "lng": float}
    }
    """
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        report_type = (data.get('type') or '').strip()
        description = (data.get('description') or '').strip()
        location = data.get('location', {})

        if not report_type or not description:
            return jsonify({'success': False, 'error': 'Type and description are required'}), 400

        report_id = str(uuid.uuid4())

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO incident_reports (id, user_id, type, description, latitude, longitude, status, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            report_id,
            user_id,
            report_type,
            description,
            location.get('lat'),
            location.get('lng'),
            'pending',
            datetime.utcnow()
        ))
        conn.commit()

        return jsonify({
            'success': True,
            'report_id': report_id,
            'message': 'Your report has been received and is being processed by the safety team.',
            'timestamp': datetime.utcnow().isoformat()
        }), 201

    except Exception as e:
        logger.error("Submit report error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        close_connection(conn)


@report_bp.route('/history', methods=['GET'])
@jwt_required()
def get_report_history():
    """Get history of reports for the authenticated user"""
    conn = None
    try:
        user_id = get_jwt_identity()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM incident_reports WHERE user_id = %s ORDER BY created_at DESC",
            (user_id,),
        )
        reports = cursor.fetchall()

        return jsonify({
            'success': True,
            'reports': [
                {**dict(r), 'created_at': str(r['created_at'])}
                for r in reports
            ]
        }), 200

    except Exception as e:
        logger.error("Report history error: %s", e)
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        close_connection(conn)
