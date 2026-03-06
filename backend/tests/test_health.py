"""
Tests for health, root, and config endpoints.
These are unauthenticated endpoints that should always be accessible.
"""

from unittest.mock import patch, MagicMock


class TestRootEndpoint:
    """Test GET / — basic API status."""

    def test_root_returns_200(self, client):
        response = client.get('/')
        assert response.status_code == 200

    def test_root_contains_version(self, client):
        data = client.get('/').get_json()
        assert 'version' in data
        assert data['status'] == 'healthy'

    def test_root_shows_auto_wake(self, client):
        data = client.get('/').get_json()
        assert data.get('auto_wake') == 'enabled'


class TestHealthEndpoint:
    """Test GET /api/health — checks DB and service statuses."""

    def test_health_returns_200(self, client, mock_db):
        mock_db['cursor'].fetchone.return_value = {'count': 5}
        response = client.get('/api/health')
        assert response.status_code == 200

    def test_health_shows_db_status(self, client, mock_db):
        mock_db['cursor'].fetchone.return_value = {'count': 3}
        data = client.get('/api/health').get_json()
        assert data['database']['status'] == 'connected'
        assert data['database']['users'] == 3

    def test_health_degraded_on_db_failure(self, client, mock_db):
        mock_db['cursor'].execute.side_effect = Exception("DB down")
        data = client.get('/api/health').get_json()
        assert data['status'] == 'degraded'

    def test_health_shows_services(self, client, mock_db):
        mock_db['cursor'].fetchone.return_value = {'count': 0}
        data = client.get('/api/health').get_json()
        assert 'services' in data
        assert data['services']['jwt_auth'] == 'ENABLED'
        assert data['services']['rate_limiting'] == 'ENABLED'


class TestConfigEndpoint:
    """Test GET /api/config — returns app configuration."""

    def test_config_returns_200(self, client):
        response = client.get('/api/config')
        assert response.status_code == 200

    def test_config_has_emergency_numbers(self, client):
        data = client.get('/api/config').get_json()
        numbers = data['emergency_numbers']
        assert numbers['police'] == '100'
        assert numbers['ambulance'] == '108'
        assert numbers['women_helpline'] == '1091'
        assert numbers['national_emergency'] == '112'

    def test_config_has_features(self, client):
        data = client.get('/api/config').get_json()
        features = data['features']
        assert features['sos_button'] is True
        assert features['ai_chatbot'] is True
        assert features['safe_accommodations'] is True

    def test_config_has_supported_regions(self, client):
        data = client.get('/api/config').get_json()
        regions = data['supported_regions']
        assert 'Chennai' in regions
        assert 'Coimbatore' in regions
        assert 'Madurai' in regions


class TestErrorHandlers:
    """Test global error handlers."""

    def test_404_on_unknown_endpoint(self, client):
        response = client.get('/api/nonexistent')
        assert response.status_code == 404
        data = response.get_json()
        assert data['success'] is False
