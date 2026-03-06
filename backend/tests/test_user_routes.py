"""
Tests for User Authentication Routes.
Covers registration, login, profile, and password change.
"""

import json
from unittest.mock import patch, MagicMock


class TestUserRegistration:
    """Test POST /api/user/register."""

    def test_register_success(self, client, mock_db):
        mock_db['cursor'].fetchone.return_value = None  # No duplicate email

        response = client.post('/api/user/register', json={
            'name': 'Priya Sharma',
            'email': 'priya@safeher.com',
            'password': 'SecurePass123',
            'phone': '9876543210',
            'city': 'Chennai',
            'consent_agreed': True,
        })

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'access_token' in data
        assert 'refresh_token' in data
        assert data['user']['email'] == 'priya@safeher.com'

    def test_register_missing_name(self, client, mock_db):
        response = client.post('/api/user/register', json={
            'email': 'test@safeher.com',
            'password': 'SecurePass123',
        })
        assert response.status_code == 400
        assert 'name' in response.get_json()['error'].lower()

    def test_register_invalid_email(self, client, mock_db):
        response = client.post('/api/user/register', json={
            'name': 'Test',
            'email': 'not-an-email',
            'password': 'SecurePass123',
        })
        assert response.status_code == 400
        assert 'email' in response.get_json()['error'].lower()

    def test_register_short_password(self, client, mock_db):
        response = client.post('/api/user/register', json={
            'name': 'Test',
            'email': 'test@safeher.com',
            'password': 'short',
        })
        assert response.status_code == 400
        assert 'password' in response.get_json()['error'].lower()

    def test_register_duplicate_email(self, client, mock_db):
        mock_db['cursor'].fetchone.return_value = {'id': 'existing-user'}

        response = client.post('/api/user/register', json={
            'name': 'Test Duplicate',
            'email': 'existing@safeher.com',
            'password': 'SecurePass123',
        })
        assert response.status_code == 409
        assert 'already registered' in response.get_json()['error'].lower()

    def test_register_with_emergency_contacts(self, client, mock_db):
        mock_db['cursor'].fetchone.return_value = None

        response = client.post('/api/user/register', json={
            'name': 'Test Contacts',
            'email': 'contacts@safeher.com',
            'password': 'SecurePass123',
            'emergency_contacts': ['9876543210', '9876543211'],
        })
        assert response.status_code == 201
        data = response.get_json()
        assert len(data['user']['emergency_contacts']) == 2


class TestUserLogin:
    """Test POST /api/user/login."""

    def test_login_success(self, client, mock_db):
        import bcrypt
        hashed = bcrypt.hashpw(b'CorrectPass123', bcrypt.gensalt()).decode('utf-8')
        mock_db['cursor'].fetchone.return_value = {
            'id': 'user-123',
            'name': 'Priya',
            'email': 'priya@safeher.com',
            'phone': '9876543210',
            'city': 'Chennai',
            'password_hash': hashed,
            'health_conditions': '',
        }
        mock_db['cursor'].fetchall.return_value = [{'contact_phone': '9876543210'}]

        response = client.post('/api/user/login', json={
            'email': 'priya@safeher.com',
            'password': 'CorrectPass123',
        })

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert 'access_token' in data
        assert data['user']['name'] == 'Priya'

    def test_login_wrong_password(self, client, mock_db):
        import bcrypt
        hashed = bcrypt.hashpw(b'CorrectPass123', bcrypt.gensalt()).decode('utf-8')
        mock_db['cursor'].fetchone.return_value = {
            'id': 'user-123',
            'name': 'Priya',
            'email': 'priya@safeher.com',
            'phone': '',
            'city': '',
            'password_hash': hashed,
            'health_conditions': '',
        }

        response = client.post('/api/user/login', json={
            'email': 'priya@safeher.com',
            'password': 'WrongPassword123',
        })
        assert response.status_code == 401

    def test_login_nonexistent_user(self, client, mock_db):
        mock_db['cursor'].fetchone.return_value = None

        response = client.post('/api/user/login', json={
            'email': 'nobody@safeher.com',
            'password': 'SomePass123',
        })
        assert response.status_code == 401

    def test_login_missing_fields(self, client, mock_db):
        response = client.post('/api/user/login', json={})
        assert response.status_code == 400


class TestUserProfile:
    """Test GET /api/user/profile — protected endpoint."""

    def test_profile_without_token(self, client):
        response = client.get('/api/user/profile')
        assert response.status_code == 401

    def test_profile_with_valid_token(self, client, mock_db, auth_headers):
        mock_db['cursor'].fetchone.return_value = {
            'id': 'user-123',
            'name': 'Test User',
            'email': 'test@safeher.com',
            'phone': '9999999999',
            'city': 'Chennai',
            'health_conditions': '',
            'created_at': '2026-01-01 00:00:00',
        }
        mock_db['cursor'].fetchall.return_value = []

        response = client.get('/api/user/profile', headers=auth_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert data['user']['email'] == 'test@safeher.com'
