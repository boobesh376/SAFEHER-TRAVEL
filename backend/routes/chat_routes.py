"""
Chat Routes — AI Safety Chatbot
JWT-protected. Stores messages in Supabase PostgreSQL.
"""

import logging
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from services.enhanced_ai_service import get_ai_response
from database.db import get_db_connection, close_connection

logger = logging.getLogger(__name__)
chat_bp = Blueprint('chat', __name__)


# ─── Send Message ─────────────────────────────────────────────────────────────

@chat_bp.route('/message', methods=['POST'])
@jwt_required(optional=True)  # Optional: works even if token expired
def send_message():
    """
    POST /api/chat/message
    Header: Authorization: Bearer <access_token>
    Body: { "message": string, "conversation_id"?: string, "user_location"?: { lat, lng } }
    Returns: { success, response, conversation_id, timestamp }
    """
    try:
        user_id = get_jwt_identity() or 'anonymous'
        data = request.get_json(force=True) or {}

        message = (data.get('message') or '').strip()
        image_data      = data.get('image')
        voice_data      = data.get('voice')

        # Allow voice-only and image-only messages (message text can be empty)
        if not message and not image_data and not voice_data:
            return jsonify({'success': False, 'error': 'Message cannot be empty'}), 400

        # For voice/image-only, set a placeholder for DB storage
        if not message:
            if voice_data:
                message = '[Voice message]'
            elif image_data:
                message = '[Photo attached]'

        conversation_id = data.get('conversation_id') or str(uuid.uuid4())
        user_location   = data.get('user_location')

        # Save user message to DB — non-blocking (DB failure won't stop AI)
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO chat_messages (id, user_id, conversation_id, message, response, sender, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (str(uuid.uuid4()), user_id, conversation_id, message, None, 'user', datetime.utcnow()),
            )
            conn.commit()
        except Exception as db_err:
            logger.warning("DB save (user msg) failed — continuing without DB: %s", db_err)
            conn = None

        # Get AI response — THIS must always succeed
        ai_response = get_ai_response(
            message,
            conversation_id,
            user_location,
            image_data=image_data,
            voice_data=voice_data,
        )

        # Save AI response to DB — non-blocking
        try:
            if conn:
                cursor.execute(
                    """
                    INSERT INTO chat_messages (id, user_id, conversation_id, message, response, sender, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (str(uuid.uuid4()), user_id, conversation_id, ai_response, None, 'assistant', datetime.utcnow()),
                )
                conn.commit()
        except Exception as db_err:
            logger.warning("DB save (AI response) failed — response still sent: %s", db_err)
        finally:
            close_connection(conn)

        return jsonify({
            'success': True,
            'conversation_id': conversation_id,
            'response': ai_response,
            'timestamp': datetime.utcnow().isoformat(),
        }), 200

    except Exception as e:
        logger.error("Chat message error: %s", e)
        # Even on catastrophic error, return a helpful AI response
        return jsonify({
            'success': True,
            'conversation_id': str(uuid.uuid4()),
            'response': "I'm here to help! 🙏 For any emergency in Tamil Nadu:\n\n🚨 Police: 100\n🚑 Ambulance: 108\n📞 National Emergency: 112\n👩 Women Helpline: 1091\n\nStay safe — what do you need help with?",
            'timestamp': datetime.utcnow().isoformat(),
        }), 200


# ─── Chat History ─────────────────────────────────────────────────────────────

@chat_bp.route('/history', methods=['GET'])
@jwt_required()
def get_chat_history():
    """
    GET /api/chat/history?limit=20
    Returns the last N messages for this user.
    """
    conn = None
    try:
        user_id = get_jwt_identity()
        limit = min(int(request.args.get('limit', 20)), 100)

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT id, conversation_id, message, sender, created_at
            FROM chat_messages
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (user_id, limit),
        )
        messages = cursor.fetchall()

        return jsonify({
            'success': True,
            'messages': [
                {**dict(m), 'created_at': str(m['created_at'])}
                for m in reversed(messages)
            ],
        }), 200

    except Exception as e:
        logger.error("Chat history error: %s", e)
        return jsonify({'success': False, 'error': 'Could not fetch chat history'}), 500
    finally:
        close_connection(conn)


# ─── Safety Tips (public) ─────────────────────────────────────────────────────

@chat_bp.route('/safety-tips', methods=['GET'])
def get_safety_tips():
    """GET /api/chat/safety-tips — no auth required"""
    tips = [
        {'id': 1, 'title': 'Share Your Location', 'description': 'Always share your live location with trusted contacts when traveling alone.', 'category': 'prevention'},
        {'id': 2, 'title': 'Trust Your Instincts', 'description': 'If a situation feels unsafe, remove yourself immediately.', 'category': 'awareness'},
        {'id': 3, 'title': 'Keep Phone Charged', 'description': 'Ensure your phone has sufficient battery when traveling.', 'category': 'preparation'},
        {'id': 4, 'title': 'Avoid Isolated Areas', 'description': 'Stay in well-lit, populated areas especially at night.', 'category': 'prevention'},
        {'id': 5, 'title': 'Use Verified Transport', 'description': 'Only use registered and verified transportation services.', 'category': 'transport'},
    ]
    return jsonify({'success': True, 'tips': tips}), 200