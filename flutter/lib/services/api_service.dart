import 'package:dio/dio.dart';
import 'storage/hive_token_storage.dart';
import 'api/dio_client.dart';
import 'storage/token_manager.dart';
import '../utils/functional_api_handler.dart';
import 'api/auth_api.dart';
import 'api/friend_api.dart';
import 'api/chat_api.dart';
import 'api/e2ee_notification_api.dart';

// Re-export AuthResponse so existing callers don't need to change their imports
export '../models/user.dart' show AuthResponse;

/// ApiService is the single public facade for all HTTP operations.
///
/// Internally organised into domain mixins:
///   - [AuthApi]         → register, login, logout, session management
///   - [FriendApi]       → friends, friend requests, user search
///   - [ChatApi]         → rooms, messages, group management
///   - [E2eeApi]         → end-to-end encryption key exchange
///   - [NotificationApi] → FCM device registration
///
/// All callers continue to import `api_service.dart` — nothing else changes.
class ApiService
    with FunctionalApiHandler, AuthApi, FriendApi, ChatApi, E2eeApi, NotificationApi {
  final String baseUrl;
  @override
  final HiveTokenStorage tokenStorage;
  late final DioClient _dioClient;
  late final TokenManager tokenManager;

  @override
  Dio get dio => _dioClient.dio;

  Future<void> Function()? _externalSessionExpiredCallback;

  ApiService({
    this.baseUrl = 'https://chat.rabiaryal.com.np',
    HiveTokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? HiveTokenStorage() {
    _dioClient = DioClient(
      tokenStorage: this.tokenStorage,
      baseUrl: baseUrl,
      onSessionExpired: () async {
        await forceLogout();
        await _externalSessionExpiredCallback?.call();
      },
    );
    tokenManager = TokenManager(tokenStorage: this.tokenStorage);
    tokenManager.attachCallbacks(
      refreshCallback: refreshAccessToken,
      sessionExpiredCallback: forceLogout,
    );
  }

  /// Set a callback to be executed when the session is expired (e.g. 401 on refresh)
  void setSessionExpiredCallback(Future<void> Function() callback) {
    _externalSessionExpiredCallback = callback;
    tokenManager.attachCallbacks(
      refreshCallback: refreshAccessToken,
      sessionExpiredCallback: () async {
        await forceLogout();
        await callback();
      },
    );
  }
}

class SessionExpiredException implements Exception {
  final String message;

  SessionExpiredException(this.message);

  @override
  String toString() => 'SessionExpiredException: $message';
}
