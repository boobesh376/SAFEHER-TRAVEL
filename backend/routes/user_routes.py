"""
User Authentication Routes
Signup, Login, Refresh Token – using bcrypt + Flask-JWT-Extended + Supabase PostgreSQL
"""

import os
import re
import logging
import bcrypt
import uuid
from flask import Blueprint, request, jsonify
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    jwt_required,
    get_jwt_identity,
)
from datetime import datetime
from database.db import get_db_connection, close_connection

logger = logging.getLogger(__name__)
user_bp = Blueprint('user', __name__)

# ─── Helpers ──────────────────────────────────────────────────────────────────

def _hash_password(password: str) -> str:
    """Hash password with bcrypt."""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def _check_password(password: str, hashed: str) -> bool:
    """Verify bcrypt password."""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def _validate_email(email: str) -> bool:
    return bool(re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', email))

def _validate_password(password: str) -> bool:
    """Minimum 8 characters."""
    return len(password) >= 8


# ─── Register ─────────────────────────────────────────────────────────────────

@user_bp.route('/register', methods=['POST'])
def register():
    """
    POST /api/user/register
    Body: { name, email, password, phone?, city?, emergency_contacts?, health_conditions?, consent_agreed? }
    Returns: { success, access_token, refresh_token, user }
    """
    conn = None
    try:
        data = request.get_json(force=True) or {}
        name  = (data.get('name') or '').strip()
        email = (data.get('email') or '').strip().lower()
        password = data.get('password') or ''
        phone = (data.get('phone') or '').strip()
        city  = (data.get('city') or '').strip()
        health_conditions = (data.get('health_conditions') or '').strip()
        consent_agreed = bool(data.get('consent_agreed', False))
        emergency_contacts = data.get('emergency_contacts', [])

        # ── Validation ────────────────────────────────────────────────────────
        if not name:
            return jsonify({'success': False, 'error': 'Full name is required'}), 400
        if not email or not _validate_email(email):
            return jsonify({'success': False, 'error': 'A valid email address is required'}), 400
        if not password or not _validate_password(password):
            return jsonify({'success': False, 'error': 'Password must be at least 8 characters'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        # Check duplicate email
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            return jsonify({'success': False, 'error': 'Email is already registered. Please login.'}), 409

        # ── Create user ───────────────────────────────────────────────────────
        user_id = str(uuid.uuid4())
        password_hash = _hash_password(password)

        cursor.execute(
            """
            INSERT INTO users (id, name, email, phone, password_hash, city, health_conditions, consent_agreed, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (user_id, name, email, phone, password_hash, city, health_conditions, consent_agreed, datetime.utcnow()),
        )

        # Save emergency contacts
        saved_contacts = []
        for contact_phone in emergency_contacts:
            phone_str = str(contact_phone).strip()
            if phone_str:
                cursor.execute(
                    """
                    INSERT INTO emergency_contacts (id, user_id, contact_name, contact_phone, relationship, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (str(uuid.uuid4()), user_id, 'Emergency Contact', phone_str, 'Emergency', datetime.utcnow()),
                )
                saved_contacts.append(phone_str)

        conn.commit()
        logger.info("New user registered: %s", email)

        # ── Issue JWT ─────────────────────────────────────────────────────────
        access_token  = create_access_token(identity=user_id)
        refresh_token = create_refresh_token(identity=user_id)

        return jsonify({
            'success': True,
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': {
                'id': user_id,
                'name': name,
                'email': email,
                'phone': phone,
                'city': city,
                'emergency_contacts': saved_contacts,
            },
        }), 201

    except Exception as e:
        import traceback
        traceback.print_exc()
        logger.error("Register error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': f'Registration failed: {str(e)}'}), 500
    finally:
        close_connection(conn)


# ─── Login ────────────────────────────────────────────────────────────────────

@user_bp.route('/login', methods=['POST'])
def login():
    """
    POST /api/user/login
    Body: { email, password }
    Returns: { success, access_token, refresh_token, user }
    Rate-limited to 5 attempts/minute by Flask-Limiter in app.py
    """
    conn = None
    try:
        data = request.get_json(force=True) or {}
        email    = (data.get('email') or '').strip().lower()
        password = data.get('password') or ''

        if not email or not password:
            return jsonify({'success': False, 'error': 'Email and password are required'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT id, name, email, phone, city, password_hash, health_conditions FROM users WHERE email = %s",
            (email,),
        )
        user = cursor.fetchone()

        if not user or not _check_password(password, user['password_hash']):
            return jsonify({'success': False, 'error': 'Invalid email or password'}), 401

        # Fetch emergency contacts
        cursor.execute(
            "SELECT contact_phone FROM emergency_contacts WHERE user_id = %s",
            (user['id'],),
        )
        contacts = [row['contact_phone'] for row in cursor.fetchall()]

        logger.info("User logged in: %s", email)

        access_token  = create_access_token(identity=user['id'])
        refresh_token = create_refresh_token(identity=user['id'])

        return jsonify({
            'success': True,
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': {
                'id': user['id'],
                'name': user['name'],
                'email': user['email'],
                'phone': user.get('phone', ''),
                'city': user.get('city', ''),
                'health_conditions': user.get('health_conditions', ''),
                'emergency_contacts': contacts,
            },
        }), 200

    except Exception as e:
        logger.error("Login error: %s", e)
        return jsonify({'success': False, 'error': 'Login failed. Please try again.'}), 500
    finally:
        close_connection(conn)


# ─── Refresh Token ────────────────────────────────────────────────────────────

@user_bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    """
    POST /api/user/refresh
    Header: Authorization: Bearer <refresh_token>
    Returns new access_token.
    """
    user_id = get_jwt_identity()
    new_access_token = create_access_token(identity=user_id)
    return jsonify({'success': True, 'access_token': new_access_token}), 200


# ─── Get Profile ──────────────────────────────────────────────────────────────

@user_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """GET /api/user/profile — protected"""
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

        cursor.execute(
            "SELECT id, contact_name, contact_phone, relationship FROM emergency_contacts WHERE user_id = %s",
            (user_id,),
        )
        contacts = cursor.fetchall()

        return jsonify({
            'success': True,
            'user': {**dict(user), 'created_at': str(user['created_at'])},
            'emergency_contacts': [dict(c) for c in contacts],
        }), 200

    except Exception as e:
        logger.error("Profile fetch error: %s", e)
        return jsonify({'success': False, 'error': 'Could not fetch profile'}), 500
    finally:
        close_connection(conn)


# ─── Change Password ──────────────────────────────────────────────────────────

@user_bp.route('/change-password', methods=['PUT'])
@jwt_required()
def change_password():
    """PUT /api/user/change-password — protected"""
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        old_password = data.get('old_password') or ''
        new_password = data.get('new_password') or ''

        if not old_password or not new_password:
            return jsonify({'success': False, 'error': 'Both old and new passwords are required'}), 400
        if not _validate_password(new_password):
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
        logger.info("Password changed for user: %s", user_id)
        return jsonify({'success': True, 'message': 'Password changed successfully'}), 200

    except Exception as e:
        logger.error("Change password error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Password change failed'}), 500
    finally:
        close_connection(conn)


# ─── Delete Account ───────────────────────────────────────────────────

@user_bp.route('/delete-account', methods=['DELETE'])
@jwt_required()
def delete_account():
    """
    DELETE /api/user/delete-account — protected
    Body: { "password": "string" }
    Permanently deletes the user and ALL associated data.
    Requires password confirmation for safety.
    """
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        password = data.get('password') or ''

        if not password:
            return jsonify({'success': False, 'error': 'Password is required to confirm account deletion'}), 400

        conn = get_db_connection()
        cursor = conn.cursor()

        # Verify user exists and password is correct
        cursor.execute("SELECT password_hash, email FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'success': False, 'error': 'User not found'}), 404

        if not _check_password(password, user['password_hash']):
            return jsonify({'success': False, 'error': 'Incorrect password. Account deletion cancelled.'}), 401

        user_email = user['email']

        # Delete all user data from every table
        # Order: child tables first, then user row
        cursor.execute("DELETE FROM emergency_contacts WHERE user_id = %s", (user_id,))
        cursor.execute("DELETE FROM sos_alerts WHERE user_id = %s", (user_id,))
        cursor.execute("DELETE FROM chat_messages WHERE user_id = %s", (user_id,))
        cursor.execute("DELETE FROM community_posts WHERE user_id = %s", (user_id,))
        cursor.execute("DELETE FROM incident_reports WHERE user_id = %s", (user_id,))

        # Finally delete the user
        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        conn.commit()

        logger.info("Account deleted: %s (user_id: %s)", user_email, user_id)

        return jsonify({
            'success': True,
            'message': 'Your account and all associated data have been permanently deleted.',
        }), 200

    except Exception as e:
        logger.error("Delete account error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Account deletion failed. Please try again.'}), 500
    finally:
        close_connection(conn)