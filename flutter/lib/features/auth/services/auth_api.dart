import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../models/user.dart';
import '../../../constants/api_constant.dart';
import '../../../utils/failure.dart';
import '../../../utils/functional_api_handler.dart';
import '../../../services/storage/hive_token_storage.dart';

/// Authentication-related API endpoints
mixin AuthApi on FunctionalApiHandler {
  Dio get dio;
  HiveTokenStorage get tokenStorage;

  /// Register a new user
  TaskEither<Failure, AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    bool persistSession = true,
  }) =>
      makeRequest(
        () => dio.post(
          ApiConstant.register,
          data: {
            'username': username,
            'email': email,
            'password': password,
            'password_confirm': password,
            'first_name': firstName ?? '',
            'last_name': lastName ?? '',
          },
          options: Options(
            validateStatus: (status) => status != null && status < 600,
          ),
        ),
        (data) async {
          final authResponse = AuthResponse.fromJson(data);
          await tokenStorage.saveTokens(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            persistSession: persistSession,
          );
          return authResponse;
        },
      );

  /// Login user and get JWT tokens
  TaskEither<Failure, AuthResponse> login({
    required String username,
    required String password,
    bool persistSession = true,
  }) =>
      makeRequest(
        () => dio.post(
          ApiConstant.login,
          data: {'username': username, 'password': password},
          options: Options(
            validateStatus: (status) => status != null && status < 600,
          ),
        ),
        (data) async {
          final authResponse = AuthResponse.fromJson(data);
          await tokenStorage.saveTokens(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            persistSession: persistSession,
          );
          return authResponse;
        },
      );

  /// Logout - invalidate refresh token
  TaskEither<Failure, void> logout() => TaskEither.tryCatch(
        () async {
          final refreshToken = tokenStorage.getRefreshToken();
          if (refreshToken != null) {
            print('📤 Sending logout request with refresh token...');
            try {
              await dio.post(
                ApiConstant.logout,
                data: {'refresh': refreshToken},
              );
              print('✓ Logout API call successful');
            } catch (e) {
              print('⚠ Logout API call failed, but clearing tokens anyway: $e');
            }
          }
          await tokenStorage.clearTokens();
          print('✓ Logout successful, tokens cleared locally');
        },
        (error, stackTrace) => ApiFailure(error.toString()),
      );

  /// Get current user info
  TaskEither<Failure, User> getCurrentUser() {
    if (tokenStorage.getAccessToken() == null) {
      return TaskEither.left(
          const AuthFailure('Authentication required - please login'));
    }
    return makeRequest(
      () => dio.get(ApiConstant.getCurrentUser),
      (data) => User.fromJson(data),
    );
  }

  /// Change password
  TaskEither<Failure, Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) =>
      makeRequest(
        () => dio.post(
          ApiConstant.changePassword,
          data: {
            'old_password': oldPassword,
            'new_password': newPassword,
            'new_password_confirm': newPasswordConfirm,
          },
        ),
        (data) => data as Map<String, dynamic>,
      );

  /// Delete user account
  TaskEither<Failure, Map<String, dynamic>> deleteUserAccount() => makeRequest(
        () => dio.delete(ApiConstant.deleteUser),
        (data) async {
          await tokenStorage.clearTokens();
          return data as Map<String, dynamic>;
        },
      );

  /// Restore session from stored tokens
  TaskEither<Failure, bool> restoreSession() => TaskEither.tryCatch(
        () async {
          final accessToken = tokenStorage.getAccessToken();
          if (accessToken == null) {
            print('⚠ No tokens found in Hive storage');
            return false;
          }
          print('✓ Session restored from Hive storage');
          return true;
        },
        (error, stackTrace) => ApiFailure(error.toString()),
      );

  /// Get token status for debugging
  Map<String, dynamic> getTokenStatus() {
    final tokens = tokenStorage.getAllTokens();
    return {
      'hasToken': tokens['accessToken'] != null,
      'accessToken': tokens['accessToken'] != null ? '***' : 'null',
      'refreshToken': tokens['refreshToken'] != null ? '***' : 'null',
    };
  }

  /// Clear local session state immediately
  Future<void> forceLogout() async {
    await tokenStorage.clearTokens();
    print('✓ Local session cleared');
  }

  /// Refresh access token using the stored refresh token
  Future<String?> refreshAccessToken() async {
    final result = await makeRequest(
      () => dio.post(
        ApiConstant.refreshToken,
        data: {'refresh': tokenStorage.getRefreshToken() ?? ''},
      ),
      (data) => data['access'] as String?,
    ).run();

    return result.fold(
      (failure) {
        print('✗ Background access token refresh error: ${failure.message}');
        if (failure is ApiFailure && failure.statusCode == 401) {
          forceLogout();
        }
        return null;
      },
      (token) {
        print('✓ Access token refreshed in background');
        return token;
      },
    );
  }
}
