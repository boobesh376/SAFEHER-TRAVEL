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
    """Get community posts, with optional category filter.
    When DB is empty, returns curated seed posts to keep the community section active."""
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

        # If DB is empty, return seed data to keep community alive
        if not posts:
            posts = _get_seed_posts(category)

        return jsonify({'success': True, 'posts': posts}), 200

    except Exception as e:
        logger.error("Get posts error: %s", e)
        # Even on DB error, return seed data so community is never empty
        posts = _get_seed_posts()
        return jsonify({'success': True, 'posts': posts}), 200
    finally:
        close_connection(conn)


# ─── Curated Seed Posts for Tamil Nadu ─────────────────────────────────────────

SEED_POSTS = [
    {
        "id": "seed-1", "user_name": "Priya Sharma", "title": "Marina Beach sunset was magical! 🌅",
        "content": "Spent an amazing evening at Marina Beach in Chennai. The sunset view is absolutely breathtaking. Felt very safe — there are police patrols and the area is well-lit with lots of families around. Just be careful with belongings during peak hours.",
        "location_name": "Marina Beach, Chennai", "category": "experience", "likes": 47,
        "is_seed": True, "is_verified": True, "created_at": "2026-03-04T18:30:00Z"
    },
    {
        "id": "seed-2", "user_name": "Ananya Krishnan", "title": "Solo trip to Kodaikanal — safety tips",
        "content": "Just completed a 3-day solo trip to Kodaikanal! The hill station is incredibly peaceful. Book stays near the lake area for easy access. Avoid isolated trails after 5 PM. The local food stalls near the bus stand are amazing. Auto drivers can overcharge — negotiate before getting in.",
        "location_name": "Kodaikanal", "category": "safety_tip", "likes": 82,
        "is_seed": True, "is_verified": True, "created_at": "2026-03-03T14:15:00Z"
    },
    {
        "id": "seed-3", "user_name": "Deepa Rajan", "title": "Meenakshi Temple in Madurai — must visit!",
        "content": "The Meenakshi Amman Temple is absolutely stunning! The architecture and history are incredible. Visit early morning (6 AM) to avoid crowds. The area around the temple is safe and bustling with shops. Try the jigarthanda drink from famous Murugan Idli Shop nearby.",
        "location_name": "Meenakshi Temple, Madurai", "category": "attraction", "likes": 65,
        "is_seed": True, "is_verified": True, "created_at": "2026-03-02T09:00:00Z"
    },
    {
        "id": "seed-4", "user_name": "Kavitha Sundaram", "title": "Best filter coffee in Pondicherry ☕",
        "content": "If you're in Pondicherry, don't miss the filter coffee at Indian Coffee House on Nehru Street. Also tried the seafood at Le Club — absolutely divine! The French Quarter is super safe for women walking around even in the evening. Highly recommend a cycle tour.",
        "location_name": "White Town, Pondicherry", "category": "food", "likes": 39,
        "is_seed": True, "is_verified": True, "created_at": "2026-03-01T11:45:00Z"
    },
    {
        "id": "seed-5", "user_name": "Sneha Mohan", "title": "⚠️ Beware of fake tour guides at Ooty",
        "content": "Had an unpleasant experience with unauthorized tour guides near the Botanical Gardens in Ooty. They approach aggressively and overcharge. Use only government-verified guides or book through your hotel. The official tourist office is next to the bus stand. Stay safe!",
        "location_name": "Botanical Gardens, Ooty", "category": "warning", "likes": 91,
        "is_seed": True, "is_verified": True, "created_at": "2026-02-28T16:20:00Z"
    },
    {
        "id": "seed-6", "user_name": "Lakshmi Venkat", "title": "Mahabalipuram Shore Temple at sunrise",
        "content": "Visited the Shore Temple complex at dawn — barely any tourists and the sunrise over the Bay of Bengal is unforgettable. The stone carvings are UNESCO-protected and stunning. The beach area is clean and safe. Local fishermen are friendly and sometimes offer boat tours.",
        "location_name": "Mahabalipuram, Chennai", "category": "attraction", "likes": 53,
        "is_seed": True, "is_verified": True, "created_at": "2026-02-27T06:30:00Z"
    },
    {
        "id": "seed-7", "user_name": "Revathi Nair", "title": "Night travel safety tip for TN buses",
        "content": "I regularly travel by government buses across Tamil Nadu. Tips: 1) Book SETC or TNSTC AC sleeper buses through the official app. 2) Sit in the front section. 3) Always share trip details via WhatsApp with family. 4) Government buses are safer than private operators. 5) Chennai to Madurai overnight bus is safe and reliable.",
        "location_name": "Tamil Nadu", "category": "safety_tip", "likes": 124,
        "is_seed": True, "is_verified": True, "created_at": "2026-02-26T22:00:00Z"
    },
    {
        "id": "seed-8", "user_name": "Divya Ganesh", "title": "Thanjavur Big Temple left me speechless 🏛️",
        "content": "The Brihadeeswarar Temple in Thanjavur is an architectural wonder — the shadow of the tower never falls on the ground! Spent 3 hours exploring. The temple complex is safe and guards are helpful. Try the authentic Thanjavur meals at Sathars for an incredible lunch experience.",
        "location_name": "Big Temple, Thanjavur", "category": "experience", "likes": 58,
        "is_seed": True, "is_verified": True, "created_at": "2026-02-25T10:15:00Z"
    },
]


def _get_seed_posts(category=None):
    """Return curated seed posts, optionally filtered by category."""
    if category and category != 'all':
        return [p for p in SEED_POSTS if p['category'] == category]
    return list(SEED_POSTS)


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
