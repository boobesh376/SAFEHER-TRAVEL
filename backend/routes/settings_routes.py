"""
Settings Routes
Manage profile, change password, and emergency contacts.
All routes are JWT-protected.
"""

import logging
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from database.db import get_db_connection, close_connection
import bcrypt

logger = logging.getLogger(__name__)
settings_bp = Blueprint('settings', __name__)


def _hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def _check_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


# ─── Profile ──────────────────────────────────────────────────────────────────

@settings_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """GET /api/settings/profile"""
    conn = None
    try:
        user_id = get_jwt_identity()
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT id, name, email, phone, city, health_conditions, created_at FROM users WHERE id = %s",
            (user_id,),
        )
        user = cursor.fetchone()
        if not user:
            return jsonify({'success': False, 'error': 'User not found'}), 404

        return jsonify({
            'success': True,
            'profile': {**dict(user), 'created_at': str(user['created_at'])},
        }), 200

    except Exception as e:
        logger.error("Settings profile error: %s", e)
        return jsonify({'success': False, 'error': 'Could not fetch profile'}), 500
    finally:
        close_connection(conn)


# ─── Change Password ──────────────────────────────────────────────────────────

@settings_bp.route('/change-password', methods=['PUT'])
@jwt_required()
def change_password():
    """PUT /api/settings/change-password"""
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        old_password = data.get('old_password') or ''
        new_password = data.get('new_password') or ''

        if not old_password or not new_password:
            return jsonify({'success': False, 'error': 'Both old and new passwords are required'}), 400
        if len(new_password) < 8:
            return jsonify({'success': False, 'error': 'New password must be at least 8 characters'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT password_hash FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user or not _check_password(old_password, user['password_hash']):
            return jsonify({'success': False, 'error': 'Current password is incorrect'}), 401

        cursor.execute(
            "UPDATE users SET password_hash = %s WHERE id = %s",
            (_hash_password(new_password), user_id),
        )
        conn.commit()
        return jsonify({'success': True, 'message': 'Password updated successfully'}), 200

    except Exception as e:
        logger.error("Change password error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Password update failed'}), 500
    finally:
        close_connection(conn)


# ─── Emergency Contacts ───────────────────────────────────────────────────────

@settings_bp.route('/emergency-contacts', methods=['GET'])
@jwt_required()
def get_emergency_contacts():
    """GET /api/settings/emergency-contacts"""
    conn = None
    try:
        user_id = get_jwt_identity()
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT id, contact_name, contact_phone, relationship, created_at FROM emergency_contacts WHERE user_id = %s ORDER BY created_at ASC",
            (user_id,),
        )
        contacts = cursor.fetchall()

        return jsonify({
            'success': True,
            'contacts': [
                {**dict(c), 'created_at': str(c['created_at'])}
                for c in contacts
            ],
        }), 200

    except Exception as e:
        logger.error("Get contacts error: %s", e)
        return jsonify({'success': False, 'error': 'Could not fetch contacts'}), 500
    finally:
        close_connection(conn)


@settings_bp.route('/emergency-contacts', methods=['POST'])
@jwt_required()
def add_emergency_contact():
    """POST /api/settings/emergency-contacts — { contact_name, contact_phone, relationship? }"""
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        contact_name  = (data.get('contact_name') or 'Emergency Contact').strip()
        contact_phone = (data.get('contact_phone') or '').strip()
        relationship  = (data.get('relationship') or 'Emergency').strip()

        if not contact_phone:
            return jsonify({'success': False, 'error': 'Contact phone number is required'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        contact_id = str(uuid.uuid4())
        cursor.execute(
            """
            INSERT INTO emergency_contacts (id, user_id, contact_name, contact_phone, relationship, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (contact_id, user_id, contact_name, contact_phone, relationship, datetime.utcnow()),
        )
        conn.commit()

        return jsonify({
            'success': True,
            'contact': {
                'id': contact_id,
                'contact_name': contact_name,
                'contact_phone': contact_phone,
                'relationship': relationship,
            },
        }), 201

    except Exception as e:
        logger.error("Add contact error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Could not add contact'}), 500
    finally:
        close_connection(conn)


@settings_bp.route('/emergency-contacts/<contact_id>', methods=['DELETE'])
@jwt_required()
def delete_emergency_contact(contact_id):
    """DELETE /api/settings/emergency-contacts/<contact_id>"""
    conn = None
    try:
        user_id = get_jwt_identity()
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "DELETE FROM emergency_contacts WHERE id = %s AND user_id = %s",
            (contact_id, user_id),
        )
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'success': False, 'error': 'Contact not found'}), 404

        return jsonify({'success': True, 'message': 'Contact removed'}), 200

    except Exception as e:
        logger.error("Delete contact error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Could not delete contact'}), 500
    finally:
        close_connection(conn)
