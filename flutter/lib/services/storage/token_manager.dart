/// Token Manager Service - Manages JWT tokens using Hive storage
import 'dart:convert';
import 'dart:async';
import 'hive_token_storage.dart';

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
  final HiveTokenStorage tokenStorage;
  Timer? _refreshTimer;
  Future<String?> Function()? _refreshCallback;
  Future<void> Function()? _sessionExpiredCallback;

  TokenManager({required HiveTokenStorage tokenStorage})
      : tokenStorage = tokenStorage;

  void attachCallbacks({
    Future<String?> Function()? refreshCallback,
    Future<void> Function()? sessionExpiredCallback,
  }) {
    _refreshCallback = refreshCallback;
    _sessionExpiredCallback = sessionExpiredCallback;
  }

  // Getters that read from Hive storage
  String? get accessToken => tokenStorage.getAccessToken();
  String? get refreshToken => tokenStorage.getRefreshToken();

  /// Decode JWT payload without verification (client-side only)
  static TokenPayload? _decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

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
    bool? persistSession,
  }) async {
    try {
      final payload = _decodeToken(accessToken);
      if (payload == null) {
        throw Exception('Invalid access token format');
      }

      await tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        persistSession: persistSession,
      );

      _scheduleTokenRefresh(payload);

      print('✓ Tokens saved to Hive storage');
      print(
          '  Access token expires in: ${payload.timeUntilExpiry.inMinutes} minutes');
    } catch (e) {
      print('Error saving tokens: $e');
      rethrow;
    }
  }

  /// Update access token
  Future<void> updateAccessToken(String newAccessToken) async {
    try {
      final payload = _decodeToken(newAccessToken);
      if (payload == null) {
        throw Exception('Invalid access token format');
      }

      final refreshToken = tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('Refresh token not found');
      }

      await tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: refreshToken,
      );

      _scheduleTokenRefresh(payload);

      print('✓ Access token updated');
      print('  New expiry in: ${payload.timeUntilExpiry.inMinutes} minutes');
    } catch (e) {
      print('Error updating access token: $e');
      rethrow;
    }
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    try {
      _refreshTimer?.cancel();
      await tokenStorage.clearTokens();
      print('✓ Tokens cleared from Hive storage');
    } catch (e) {
      print('Error clearing tokens: $e');
      rethrow;
    }
  }

  /// Schedule automatic token refresh
  void _scheduleTokenRefresh(TokenPayload payload) {
    _refreshTimer?.cancel();

    final timeUntilRefresh = payload.timeUntilExpiry - Duration(minutes: 5);

    if (timeUntilRefresh.isNegative) {
      print('⚠ Token expires within 5 minutes, refreshing immediately');
      _refreshTimer = Timer(Duration.zero, _handleTokenRefresh);
      return;
    }

    _refreshTimer = Timer(timeUntilRefresh, _handleTokenRefresh);
    print(
        '📅 Token refresh scheduled in ${timeUntilRefresh.inMinutes} minutes');
  }

  Future<void> _handleTokenRefresh() async {
    print('⏱ Scheduled token refresh triggered');

    final refreshCallback = _refreshCallback;
    if (refreshCallback == null) {
      print('⚠ No refresh callback registered - skipping background refresh');
      return;
    }

    try {
      final newAccessToken = await refreshCallback();
      if (newAccessToken == null) {
        print('✗ Background refresh failed - refresh token likely expired');
        await _sessionExpiredCallback?.call();
        await clearTokens();
        return;
      }

      await updateAccessToken(newAccessToken);
      print('✓ Background access token refresh completed');
    } catch (e) {
      print('✗ Background token refresh error: $e');
      await _sessionExpiredCallback?.call();
      await clearTokens();
    }
  }

  /// Get token status for debugging
  Map<String, dynamic> getTokenStatus() {
    final accessToken = tokenStorage.getAccessToken();
    if (accessToken == null) {
      return {
        'hasToken': false,
        'isExpired': true,
        'expiresAt': null,
        'expiresIn': null,
        'userId': null,
        'username': null,
        'email': null,
      };
    }

    final payload = _decodeToken(accessToken);
    return {
      'hasToken': true,
      'isExpired': payload?.isExpired ?? true,
      'expiresAt': payload?.expiresAt.toIso8601String(),
      'expiresIn': payload?.timeUntilExpiry.inMinutes,
      'userId': payload?.userId,
      'username': payload?.username,
      'email': payload?.email,
    };
  }

  void debugPrintTokenInfo() {
    final status = getTokenStatus();
    print('=== Token Status ===');
    print('Has Token: ${status['hasToken']}');
    print('Is Expired: ${status['isExpired']}');
    print('Expires At: ${status['expiresAt']}');
    print('Expires In: ${status['expiresIn']} minutes');
    print('User ID: ${status['userId']}');
    print('Username: ${status['username']}');
    print('Email: ${status['email']}');
    print('===================');
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
  }
}
