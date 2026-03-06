"""
Tests for SOS Emergency Routes.
Covers SOS trigger, history, and deactivation.
"""

from unittest.mock import patch


class TestSOSTrigger:
    """Test POST /api/sos/trigger — JWT protected."""

    def test_sos_requires_auth(self, client):
        response = client.post('/api/sos/trigger', json={
            'latitude': 13.0417,
            'longitude': 80.2338,
        })
        assert response.status_code == 401

    def test_sos_missing_location(self, client, auth_headers, mock_db):
        # Patch police and notification services so they don't fail
        with patch('routes.sos_routes.alert_nearest_police', return_value=[]):
            response = client.post('/api/sos/trigger',
                                   json={},
                                   headers=auth_headers)
            assert response.status_code == 400
            assert 'latitude' in response.get_json()['error'].lower() or 'longitude' in response.get_json()['error'].lower()

    def test_sos_trigger_success(self, client, auth_headers, mock_db):
        mock_db['cursor'].fetchone.return_value = {'name': 'Test User'}
        mock_db['cursor'].fetchall.return_value = [{'contact_phone': '9876543210'}]

        with patch('routes.sos_routes.alert_nearest_police', return_value=[{
            'name': 'Test Station', 'phone': '100', 'distance_km': 1.5, 'eta_minutes': 3
        }]):
            with patch('routes.sos_routes.send_sms'):
                with patch('routes.sos_routes.generate_whatsapp_links', return_value=[]):
                    response = client.post('/api/sos/trigger',
                                           json={'latitude': 13.0417, 'longitude': 80.2338},
                                           headers=auth_headers)
                    assert response.status_code == 200
                    data = response.get_json()
                    assert data['success'] is True
                    assert 'sos_id' in data


class TestSOSHistory:
    """Test GET /api/sos/history — JWT protected."""

    def test_history_requires_auth(self, client):
        response = client.get('/api/sos/history')
        assert response.status_code == 401

    def test_history_returns_empty(self, client, auth_headers, mock_db):
        mock_db['cursor'].fetchall.return_value = []
        response = client.get('/api/sos/history', headers=auth_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert data['alerts'] == []
