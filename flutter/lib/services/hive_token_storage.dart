/// Hive-based token storage service for secure token persistence
import 'package:hive_flutter/hive_flutter.dart';

class HiveTokenStorage {
  static const String _boxName = 'chat_tokens';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Singleton instance
  static HiveTokenStorage? _instance;

  late Box<String> _tokenBox;
  bool _isInitialized = false;

  // Private constructor
  HiveTokenStorage._internal();

  /// Get singleton instance
  static HiveTokenStorage get instance {
    _instance ??= HiveTokenStorage._internal();
    return _instance!;
  }

  /// Factory constructor for convenience
  factory HiveTokenStorage() {
    return instance;
  }

  /// Initialize Hive storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      _tokenBox = await Hive.openBox<String>(_boxName);
      _isInitialized = true;
      print('✓ Hive token storage initialized');
    } catch (e) {
      print('✗ Error initializing Hive storage: $e');
      rethrow;
    }
  }

  /// Save access and refresh tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (!_isInitialized) {
      print('⚠ HiveTokenStorage not initialized yet - cannot save tokens');
      return;
    }
    try {
      await Future.wait([
        _tokenBox.put(_accessTokenKey, accessToken),
        _tokenBox.put(_refreshTokenKey, refreshToken),
      ]);
      print('✓ Tokens saved to Hive storage');
    } catch (e) {
      print('✗ Error saving tokens to Hive: $e');
      rethrow;
    }
  }

  /// Get access token
  String? getAccessToken() {
    if (!_isInitialized) {
      print('⚠ HiveTokenStorage not initialized - cannot read access token');
      return null;
    }
    try {
      return _tokenBox.get(_accessTokenKey);
    } catch (e) {
      print('✗ Error reading access token: $e');
      return null;
    }
  }

  /// Get refresh token
  String? getRefreshToken() {
    if (!_isInitialized) {
      print('⚠ HiveTokenStorage not initialized - cannot read refresh token');
      return null;
    }
    try {
      return _tokenBox.get(_refreshTokenKey);
    } catch (e) {
      print('✗ Error reading refresh token: $e');
      return null;
    }
  }

  /// Check if tokens exist
  bool hasTokens() {
    if (!_isInitialized) {
      print('⚠ HiveTokenStorage not initialized - no tokens available');
      return false;
    }
    try {
      return _tokenBox.containsKey(_accessTokenKey) &&
          _tokenBox.containsKey(_refreshTokenKey);
    } catch (e) {
      print('✗ Error checking tokens: $e');
      return false;
    }
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    if (!_isInitialized) {
      print('⚠ HiveTokenStorage not initialized - cannot clear tokens');
      return;
    }
    try {
      await Future.wait([
        _tokenBox.delete(_accessTokenKey),
        _tokenBox.delete(_refreshTokenKey),
      ]);
      print('✓ Tokens cleared from Hive storage');
    } catch (e) {
      print('✗ Error clearing tokens: $e');
      rethrow;
    }
  }

  /// Get all stored tokens (for debugging)
  Map<String, String?> getAllTokens() {
    return {
      'accessToken': getAccessToken(),
      'refreshToken': getRefreshToken(),
    };
  }

  /// Close Hive box
  Future<void> close() async {
    try {
      if (_isInitialized) {
        await _tokenBox.close();
        _isInitialized = false;
        print('✓ Hive token storage closed');
      }
    } catch (e) {
      print('✗ Error closing Hive storage: $e');
    }
  }
}
