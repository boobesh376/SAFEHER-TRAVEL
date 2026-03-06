"""
SafeHer – Flask Backend
Production-ready with JWT, rate limiting, Supabase PostgreSQL, and structured logging.
"""

import os
import logging
from datetime import timedelta
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv

# ─── Load environment ─────────────────────────────────────────────────────────
load_dotenv()

# ─── Auto-wake Supabase (free-tier pausing) ───────────────────────────────────
from services.supabase_wake import ensure_supabase_awake
ensure_supabase_awake()

# ─── Structured logging ───────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
)
logger = logging.getLogger('safeher')

# ─── Flask app ────────────────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})

# ─── Configuration ────────────────────────────────────────────────────────────
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'change-me-in-production')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jwt-change-me-in-production')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(
    days=int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES_DAYS', 7))
)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = timedelta(days=30)

# ─── Extensions ───────────────────────────────────────────────────────────────
jwt = JWTManager(app)

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"],
    storage_uri="memory://",
)

# ─── JWT error handlers ───────────────────────────────────────────────────────
@jwt.unauthorized_loader
def missing_token_callback(reason):
    return jsonify({'success': False, 'error': 'Authorization token required', 'reason': reason}), 401

@jwt.invalid_token_loader
def invalid_token_callback(reason):
    return jsonify({'success': False, 'error': 'Invalid token', 'reason': reason}), 422

@jwt.expired_token_loader
def expired_token_callback(jwt_header, jwt_payload):
    return jsonify({'success': False, 'error': 'Token has expired. Please login again.'}), 401

@jwt.revoked_token_loader
def revoked_token_callback(jwt_header, jwt_payload):
    return jsonify({'success': False, 'error': 'Token has been revoked.'}), 401

# ─── Import & register blueprints ─────────────────────────────────────────────
from routes.user_routes import user_bp
from routes.sos_routes import sos_bp
from routes.chat_routes import chat_bp
from routes.settings_routes import settings_bp
from routes.location_routes import location_bp
from routes.resources_routes import resources_bp
from routes.accommodations_routes import accommodations_bp
from routes.community_routes import community_bp
from routes.report_routes import report_bp

app.register_blueprint(user_bp,           url_prefix='/api/user')
app.register_blueprint(sos_bp,            url_prefix='/api/sos')
app.register_blueprint(chat_bp,           url_prefix='/api/chat')
app.register_blueprint(settings_bp,       url_prefix='/api/settings')
app.register_blueprint(location_bp,       url_prefix='/api/location')
app.register_blueprint(resources_bp,      url_prefix='/api/resources')
app.register_blueprint(accommodations_bp, url_prefix='/api/accommodations')
app.register_blueprint(community_bp,      url_prefix='/api/community')
app.register_blueprint(report_bp,         url_prefix='/api/report')

# ─── Health check ─────────────────────────────────────────────────────────────
@app.route('/')
def index():
    return jsonify({
        'message': 'SafeHer API is running',
        'version': '3.1',
        'status': 'healthy',
        'database': 'Supabase PostgreSQL',
        'auto_wake': 'enabled',
    }), 200


@app.route('/api/health')
def health_check():
    from database.db import get_db_connection, close_connection
    db_status = 'error'
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) AS count FROM users")
        user_count = cursor.fetchone()['count']
        db_status = 'connected'
    except Exception as e:
        logger.error("Health-check DB error: %s", e)
        user_count = 0
    finally:
        close_connection(conn)

    return jsonify({
        'status': 'healthy' if db_status == 'connected' else 'degraded',
        'database': {
            'type': 'Supabase PostgreSQL',
            'status': db_status,
            'users': user_count,
        },
        'services': {
            'ai_chatbot': 'ONLINE' if os.getenv('GEMINI_API_KEY') else 'OFFLINE',
            'jwt_auth': 'ENABLED',
            'rate_limiting': 'ENABLED',
            'twilio_sms': 'configured' if os.getenv('TWILIO_ACCOUNT_SID') else 'disabled',
        },
    }), 200


@app.route('/api/config')
def get_config():
    return jsonify({
        'emergency_numbers': {
            'police': '100',
            'ambulance': '108',
            'national_emergency': '112',
            'women_helpline': '1091',
            'child_helpline': '1098',
        },
        'features': {
            'sos_button': True,
            'live_location_sharing': True,
            'ai_chatbot': True,
            'nearby_resources': True,
            'safe_accommodations': True,
        },
        'supported_regions': [
            'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli',
            'Salem', 'Tirunelveli', 'Vellore', 'Thanjavur',
            'Kanyakumari', 'Kodaikanal', 'Ooty', 'Pondicherry',
        ],
    }), 200


# ─── Global error handlers ────────────────────────────────────────────────────
@app.errorhandler(404)
def not_found(error):
    return jsonify({'success': False, 'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    logger.error("Internal server error: %s", error)
    return jsonify({'success': False, 'error': 'Internal server error. Please try again later.'}), 500


@app.errorhandler(400)
def bad_request(error):
    return jsonify({'success': False, 'error': 'Bad request. Check your input data.'}), 400


@app.errorhandler(429)
def rate_limit_exceeded(error):
    return jsonify({'success': False, 'error': 'Too many requests. Please wait and try again.'}), 429


# ─── Entry point ──────────────────────────────────────────────────────────────
if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV', 'production') == 'development'

    logger.info("=" * 50)
    logger.info("SafeHer API v3.1")
    logger.info("Port: %s | Debug: %s | DB: Supabase PostgreSQL", port, debug)
    logger.info("=" * 50)

    app.run(host='0.0.0.0', port=port, debug=debug)