import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Central API service. Automatically attaches JWT bearer token to
/// all protected requests. Handles 401 token refresh.
class ApiService {
  // ─── Base URL Configuration ──────────────────────────────────────────────
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'http://localhost:5000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    return 'http://localhost:5000/api';
  }

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String password,
    required List<String> emergencyContacts,
    String? healthConditions,
    bool consentAgreed = false,
  }) async {
    final res = await _post('/user/register', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'city': city,
      'emergency_contacts': emergencyContacts,
      'health_conditions': healthConditions ?? '',
      'consent_agreed': consentAgreed,
    }, requiresAuth: false);

    if (res['success'] == true) {
      await AuthService.saveSession(
        accessToken:  res['access_token']  ?? '',
        refreshToken: res['refresh_token'] ?? '',
        user:         res['user'] ?? {},
      );
    }
    return res;
  }

  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _post(
      '/user/login',
      {'email': email, 'password': password},
      requiresAuth: false,
    );

    if (res['success'] == true) {
      await AuthService.saveSession(
        accessToken:  res['access_token']  ?? '',
        refreshToken: res['refresh_token'] ?? '',
        user:         res['user'] ?? {},
      );
    }
    return res;
  }

  Future<bool> refreshToken() async {
    final refreshToken = await AuthService.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['access_token'] != null) {
        await AuthService.updateAccessToken(data['access_token']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ─── Profile / Settings ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() =>
      _get('/settings/profile');

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) =>
      _put('/settings/change-password', {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

  Future<Map<String, dynamic>> getEmergencyContacts() =>
      _get('/settings/emergency-contacts');

  Future<Map<String, dynamic>> addEmergencyContact({
    required String contactName,
    required String contactPhone,
    String relationship = 'Emergency',
  }) =>
      _post('/settings/emergency-contacts', {
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'relationship': relationship,
      });

  Future<Map<String, dynamic>> deleteEmergencyContact(String contactId) =>
      _delete('/settings/emergency-contacts/$contactId');

  // ─── SOS ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> triggerSOS({
    required double lat,
    required double lng,
  }) =>
      _post('/sos/trigger', {'latitude': lat, 'longitude': lng});

  Future<Map<String, dynamic>> deactivateSOS(String sosId) =>
      _post('/sos/deactivate/$sosId', {});

  Future<Map<String, dynamic>> getSOSHistory() =>
      _get('/sos/history');

  Future<Map<String, dynamic>> updateSOSLocation({
    required String sosId,
    required double lat,
    required double lng,
  }) =>
      _post('/sos/update-location/$sosId', {'latitude': lat, 'longitude': lng});

  // ─── Chat ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? conversationId,
    Map<String, double>? location,
    String? imageBase64,
    String? voiceBase64,
  }) =>
      _post('/chat/message', {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (location != null) 'user_location': location,
        if (imageBase64 != null) 'image': imageBase64,
        if (voiceBase64 != null) 'voice': voiceBase64,
      });

  Future<Map<String, dynamic>> getChatHistory({int limit = 20}) =>
      _get('/chat/history?limit=$limit');

  // ─── Other Existing Endpoints (legacy – no auth required) ────────────────

  Future<Map<String, dynamic>> getNearbyPolice(double lat, double lng,
      {int radius = 10000}) =>
      _get('/resources/police-stations?lat=$lat&lng=$lng&radius=$radius',
          requiresAuth: false);

  Future<Map<String, dynamic>> getNearbyHospitals(double lat, double lng,
      {int radius = 10000}) =>
      _get('/resources/hospitals?lat=$lat&lng=$lng&radius=$radius',
          requiresAuth: false);

  Future<Map<String, dynamic>> getNearbyHotels(double lat, double lng) =>
      _get('/accommodations/search?lat=$lat&lng=$lng&female_friendly=true',
          requiresAuth: false);

  Future<Map<String, dynamic>> getCommunityPosts() =>
      _get('/community/posts', requiresAuth: false);

  Future<Map<String, dynamic>> createCommunityPost({
    required String userName,
    required String title,
    required String content,
    required String locationName,
    String category = 'experience',
  }) async {
    final user = await AuthService.getUser();
    return _post('/community/posts', {
      'user_id': user?['id'] ?? '',
      'user_name': userName,
      'title': title,
      'content': content,
      'location_name': locationName,
      'category': category,
    }, requiresAuth: false);
  }

  Future<Map<String, dynamic>> likePost(String postId) =>
      _post('/community/posts/$postId/like', {}, requiresAuth: false);

  Future<Map<String, dynamic>> submitReport({
    required String type,
    required String description,
    required double lat,
    required double lng,
  }) async {
    final user = await AuthService.getUser();
    return _post('/report/submit', {
      'user_id': user?['id'] ?? '',
      'type': type,
      'description': description,
      'location': {'lat': lat, 'lng': lng},
    }, requiresAuth: false);
  }

  // ─── HTTP Helpers ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String endpoint,
      {bool requiresAuth = true}) async {
    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response =
          await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      return _handleResponse(response, endpoint, requiresAuth: requiresAuth);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> body,
      {bool requiresAuth = true}) async {
    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response, endpoint, requiresAuth: requiresAuth);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _put(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _buildHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response, endpoint);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _delete(String endpoint) async {
    try {
      final headers = await _buildHeaders();
      final response =
          await http.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
      return _handleResponse(response, endpoint);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, String>> _buildHeaders(
      {bool requiresAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Handles 401 by attempting a token refresh, then retrying once.
  Future<Map<String, dynamic>> _handleResponse(
      http.Response response, String endpoint,
      {bool requiresAuth = true}) async {
    if (response.statusCode == 401 && requiresAuth) {
      // Try refreshing
      final refreshed = await refreshToken();
      if (refreshed) {
        // Retry original request once with new token
        final headers = await _buildHeaders();
        final retried = await http.get(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers);
        if (retried.statusCode != 401) {
          return jsonDecode(retried.body) as Map<String, dynamic>;
        }
      }
      await AuthService.logout();
      return {'success': false, 'error': 'Session expired. Please login again.', 'session_expired': true};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}