"""
Community Routes - Tourist Experience Sharing
Allows users to share and read travel experiences.
Uses Supabase PostgreSQL (psycopg2).
"""

import logging
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from database.db import get_db_connection, close_connection

logger = logging.getLogger(__name__)
community_bp = Blueprint('community', __name__)


@community_bp.route('/posts', methods=['GET'])
def get_posts():
    """Get community posts, with optional category filter."""
    conn = None
    try:
        category = request.args.get('category')
        conn = get_db_connection()
        cursor = conn.cursor()

        if category and category != 'all':
            cursor.execute("""
                SELECT * FROM community_posts
                WHERE category = %s
                ORDER BY created_at DESC LIMIT 50
            """, (category,))
        else:
            cursor.execute("""
                SELECT * FROM community_posts ORDER BY created_at DESC LIMIT 50
            """)

        rows = cursor.fetchall()
        posts = [dict(row) for row in rows]

        # Serialize timestamps
        for post in posts:
            if post.get('created_at'):
                post['created_at'] = str(post['created_at'])

        return jsonify({'success': True, 'posts': posts}), 200

    except Exception as e:
        logger.error("Get posts error: %s", e)
        return jsonify({'success': True, 'posts': []}), 200
    finally:
        close_connection(conn)


@community_bp.route('/posts', methods=['POST'])
@jwt_required()
def create_post():
    """Create a new community post."""
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}
        title = (data.get('title') or '').strip()
        content = (data.get('content') or '').strip()
        location_name = (data.get('location_name') or '').strip()
        user_name = (data.get('user_name') or 'Traveler').strip()
        category = (data.get('category') or 'experience').strip()

        if not title or not content:
            return jsonify({'success': False, 'error': 'Title and content are required'}), 400

        post_id = str(uuid.uuid4())
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO community_posts (id, user_id, user_name, title, content, location_name, category, likes, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 0, %s)
        """, (post_id, user_id, user_name, title, content, location_name, category, datetime.utcnow()))
        conn.commit()

        return jsonify({'success': True, 'post_id': post_id, 'message': 'Post created successfully'}), 201

    except Exception as e:
        logger.error("Create post error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        close_connection(conn)


@community_bp.route('/posts/<post_id>/like', methods=['POST'])
@jwt_required()
def like_post(post_id):
    """Like a post."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE community_posts SET likes = likes + 1 WHERE id = %s", (post_id,))
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({'success': False, 'error': 'Post not found'}), 404

        cursor.execute("SELECT likes FROM community_posts WHERE id = %s", (post_id,))
        row = cursor.fetchone()

        return jsonify({'success': True, 'likes': row['likes']}), 200

    except Exception as e:
        logger.error("Like post error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        close_connection(conn)
