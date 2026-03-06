import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages JWT tokens and user session using flutter_secure_storage.
/// Tokens are stored encrypted on the device keychain/keystore.
class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccessToken  = 'safeher_access_token';
  static const _keyRefreshToken = 'safeher_refresh_token';
  static const _keyUser         = 'safeher_user';

  // ─── Session ──────────────────────────────────────────────────────────────

  /// Save JWT tokens and user data after login/signup.
  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken,  value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUser,         value: jsonEncode(user)),
    ]);
  }

  /// Returns true if a valid (non-empty) access token exists.
  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _keyAccessToken);
    return token != null && token.isNotEmpty;
  }

  /// Returns the current access token, or null if none.
  static Future<String?> getToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  /// Returns the refresh token, or null if none.
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// Updates just the access token (used after a token refresh).
  static Future<void> updateAccessToken(String newToken) async {
    await _storage.write(key: _keyAccessToken, value: newToken);
  }

  /// Returns the stored user object, or null.
  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: _keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clears all stored tokens and user data (logout).
  static Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUser),
    ]);
  }
}
