"""
Pytest Fixtures for SafeHer Backend Tests
Provides Flask test client, mock DB connection, and auth helpers.
"""

import os
import sys
import pytest
from unittest.mock import MagicMock, patch

# Ensure the backend package is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


# The list of modules that import get_db_connection and need to be patched.
# Each route file does: from database.db import get_db_connection
# So we must patch where it's USED, not where it's DEFINED.
_DB_PATCH_TARGETS = [
    'database.db.get_db_connection',
    'app.get_db_connection',
    'routes.user_routes.get_db_connection',
    'routes.sos_routes.get_db_connection',
    'routes.chat_routes.get_db_connection',
    'routes.settings_routes.get_db_connection',
    'routes.location_routes.get_db_connection',
    'routes.resources_routes.get_db_connection',
    'routes.community_routes.get_db_connection',
    'routes.report_routes.get_db_connection',
]

_CLOSE_PATCH_TARGETS = [
    'database.db.close_connection',
    'app.close_connection',
    'routes.user_routes.close_connection',
    'routes.sos_routes.close_connection',
    'routes.chat_routes.close_connection',
    'routes.settings_routes.close_connection',
    'routes.location_routes.close_connection',
    'routes.resources_routes.close_connection',
    'routes.community_routes.close_connection',
    'routes.report_routes.close_connection',
]


@pytest.fixture(scope='session')
def app():
    """Create the Flask application for testing."""
    # Patch auto-wake before first import to prevent real API calls
    with patch('services.supabase_wake.ensure_supabase_awake', return_value=True):
        from app import app as flask_app

    flask_app.config.update({
        'TESTING': True,
        'JWT_SECRET_KEY': 'test-jwt-secret',
        'SECRET_KEY': 'test-secret',
    })
    return flask_app


@pytest.fixture
def client(app):
    """Flask test client — use this to make requests in tests."""
    return app.test_client()


@pytest.fixture
def mock_db():
    """
    Mock database connection & cursor across ALL route modules.

    Patches get_db_connection everywhere it is imported so that test
    requests to any endpoint will use the mock instead of real Supabase.

    Usage:
        def test_something(client, mock_db):
            mock_db['cursor'].fetchone.return_value = {'id': '123'}
            response = client.get('/api/...')
    """
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    patches = []
    for target in _DB_PATCH_TARGETS:
        p = patch(target, return_value=mock_conn)
        patches.append(p)
    for target in _CLOSE_PATCH_TARGETS:
        p = patch(target)
        patches.append(p)

    for p in patches:
        p.start()

    yield {
        'conn': mock_conn,
        'cursor': mock_cursor,
    }

    for p in patches:
        p.stop()


@pytest.fixture
def auth_headers(client, mock_db):
    """
    Register a test user and return headers with a valid JWT.
    Usage:
        def test_protected(client, auth_headers):
            response = client.get('/api/user/profile', headers=auth_headers)
    """
    # Mock: no existing user with this email
    mock_db['cursor'].fetchone.return_value = None  # email check returns no user

    response = client.post('/api/user/register', json={
        'name': 'Test User',
        'email': 'test@safeher.com',
        'password': 'TestPass1234',
        'phone': '9999999999',
        'city': 'Chennai',
    })

    data = response.get_json()
    token = data.get('access_token', '')
    return {'Authorization': f'Bearer {token}'}
