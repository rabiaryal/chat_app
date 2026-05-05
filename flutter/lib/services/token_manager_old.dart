/// Token Manager Service - Manages JWT tokens and automatic refresh
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:async';

class TokenPayload {
  final String userId;
  final String username;
  final String email;
  final DateTime expiresAt;
  final DateTime issuedAt;

  TokenPayload({
    required this.userId,
    required this.username,
    required this.email,
    required this.expiresAt,
    required this.issuedAt,
  });

  /// Check if token is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if token expires within specified duration
  bool expiresWithin(Duration duration) {
    return DateTime.now().add(duration).isAfter(expiresAt);
  }

  /// Time until expiry
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
}

class TokenManager {
  final FlutterSecureStorage _secureStorage;
  static const String _accessTokenKey = 'jwt_access_token';
  static const String _refreshTokenKey = 'jwt_refresh_token';
  static const String _userDataKey = 'user_data';

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  TokenPayload? _cachedPayload;
  Timer? _refreshTimer;

  TokenManager({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // Getters
  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;
  TokenPayload? get payload => _cachedPayload;
  bool get hasValidToken =>
      _cachedAccessToken != null && !(_cachedPayload?.isExpired ?? true);

  /// Decode JWT payload without verification (client-side only)
  static TokenPayload? _decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode payload with padding
      String payload = parts[1];
      payload += '=' * (4 - payload.length % 4);
      final decoded = jsonDecode(utf8.decode(base64.decode(payload)));

      return TokenPayload(
        userId: (decoded['user_id'] ?? decoded['sub'] ?? '').toString(),
        username: decoded['username'] ?? 'Unknown',
        email: decoded['email'] ?? '',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (decoded['exp'] ?? 0) * 1000,
        ),
        issuedAt: DateTime.fromMillisecondsSinceEpoch(
          (decoded['iat'] ?? 0) * 1000,
        ),
      );
    } catch (e) {
      print('Error decoding token: $e');
      return null;
    }
  }

  /// Save tokens after login/registration
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? userData,
  }) async {
    try {
      // Decode payload to validate
      final payload = _decodeToken(accessToken);
      if (payload == null) {
        throw Exception('Invalid access token format');
      }

      // Save to secure storage
      await _secureStorage.write(
        key: _accessTokenKey,
        value: accessToken,
      );
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: refreshToken,
      );

      // Cache in memory
      _cachedAccessToken = accessToken;
      _cachedRefreshToken = refreshToken;
      _cachedPayload = payload;

      // Schedule auto refresh
      _scheduleTokenRefresh();

      print('✓ Tokens saved successfully');
      print(
          '  Access token expires in: ${payload.timeUntilExpiry.inMinutes} minutes');
    } catch (e) {
      print('Error saving tokens: $e');
      rethrow;
    }
  }

  /// Load tokens from secure storage
  Future<bool> loadTokens() async {
    try {
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      if (accessToken == null || refreshToken == null) {
        print('⚠ No tokens found in secure storage');
        return false;
      }

      // Decode and validate
      final payload = _decodeToken(accessToken);
      if (payload == null) {
        print('✗ Invalid token format in storage');
        return false;
      }

      // Cache in memory
      _cachedAccessToken = accessToken;
      _cachedRefreshToken = refreshToken;
      _cachedPayload = payload;

      // Schedule auto refresh if token not expired
      if (!payload.isExpired) {
        _scheduleTokenRefresh();
        print('✓ Tokens loaded from secure storage');
        print(
            '  Access token expires in: ${payload.timeUntilExpiry.inMinutes} minutes');
        return true;
      } else {
        print('✗ Access token has expired');
        return false;
      }
    } catch (e) {
      print('Error loading tokens: $e');
      return false;
    }
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    try {
      _refreshTimer?.cancel();
      _refreshTimer = null;

      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _userDataKey);

      // Clear from memory
      _cachedAccessToken = null;
      _cachedRefreshToken = null;
      _cachedPayload = null;

      print('✓ Tokens cleared');
    } catch (e) {
      print('Error clearing tokens: $e');
      rethrow;
    }
  }

  /// Schedule automatic token refresh before expiry (5 minutes before)
  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();

    if (_cachedPayload == null || _cachedPayload!.isExpired) {
      return;
    }

    final timeUntilRefresh =
        _cachedPayload!.timeUntilExpiry - Duration(minutes: 5);

    if (timeUntilRefresh.isNegative) {
      // Token expires within 5 minutes, refresh immediately
      _performTokenRefresh();
    } else {
      // Schedule refresh for later
      _refreshTimer = Timer(timeUntilRefresh, () {
        _performTokenRefresh();
      });

      print(
        '⏱ Token refresh scheduled in '
        '${timeUntilRefresh.inMinutes} minutes',
      );
    }
  }

  /// Perform token refresh (to be called by API service with refresh endpoint)
  Future<void> updateAccessToken(String newAccessToken) async {
    try {
      final payload = _decodeToken(newAccessToken);
      if (payload == null) {
        throw Exception('Invalid new access token');
      }

      _cachedAccessToken = newAccessToken;
      _cachedPayload = payload;

      // Save to storage
      await _secureStorage.write(
        key: _accessTokenKey,
        value: newAccessToken,
      );

      // Reschedule refresh
      _scheduleTokenRefresh();

      print('✓ Access token refreshed');
      print('  New expiry: ${payload.timeUntilExpiry.inMinutes} minutes');
    } catch (e) {
      print('Error updating access token: $e');
      rethrow;
    }
  }

  /// Internal method for API service to call when refreshing
  Future<void> _performTokenRefresh() {
    print('Attempting to refresh token...');
    // This will be called by API service
    return Future.value();
  }

  /// Get authorization header for HTTP requests
  String getAuthorizationHeader() {
    if (_cachedAccessToken == null) {
      throw Exception('No access token available');
    }
    return 'Bearer $_cachedAccessToken';
  }

  /// Check token validity and status
  Map<String, dynamic> getTokenStatus() {
    return {
      'hasToken': _cachedAccessToken != null,
      'isExpired': _cachedPayload?.isExpired ?? true,
      'expiresAt': _cachedPayload?.expiresAt.toIso8601String(),
      'expiresIn': _cachedPayload?.timeUntilExpiry.inMinutes,
      'userId': _cachedPayload?.userId,
      'username': _cachedPayload?.username,
      'email': _cachedPayload?.email,
    };
  }

  /// Debug: Print token details
  void debugPrintTokenInfo() {
    if (_cachedPayload == null) {
      print('⚠ No token loaded');
      return;
    }

    print('╔════════════════════════════════════════╗');
    print('║         TOKEN INFORMATION              ║');
    print('╠════════════════════════════════════════╣');
    print('║ User ID: ${_cachedPayload!.userId}');
    print('║ Username: ${_cachedPayload!.username}');
    print('║ Email: ${_cachedPayload!.email}');
    print('║ Issued: ${_cachedPayload!.issuedAt}');
    print('║ Expires: ${_cachedPayload!.expiresAt}');
    print(
        '║ Time until expiry: ${_cachedPayload!.timeUntilExpiry.inMinutes} min');
    print('║ Is expired: ${_cachedPayload!.isExpired}');
    print('╚════════════════════════════════════════╝');
  }
}
