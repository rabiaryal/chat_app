/// Auth State Management using Provider
import 'dart:async';

import 'package:chat_app/constants/api_constant.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/realtime/chat_controller.dart';
import '../services/notification_service.dart';
import '../services/storage/chat_persistence_service.dart';
import '../services/storage/friend_persistence_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService apiService;
  final NotificationService notificationService;

  User? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticating = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isNewUser = false;
  int _authEpoch = 0;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticating => _isAuthenticating;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isNewUser => _isNewUser;

  AuthProvider({
    required this.apiService,
    required this.notificationService,
  }) {
    notificationService.setSessionExpiredCallback(handleSessionExpired);
  }

  /// Initialize auth state - restore session if available
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final hasLocalSession = apiService.tokenStorage.hasAccessToken();
    _isAuthenticated = hasLocalSession;
    _isLoading = false;
    notifyListeners();

    if (hasLocalSession) {
      final validationEpoch = _authEpoch;
      unawaited(_validateSessionInBackground(validationEpoch));
    }
  }

  Future<void> _validateSessionInBackground(int validationEpoch) async {
    final restoreResult = await apiService.restoreSession().run();

    if (validationEpoch != _authEpoch) {
      return;
    }

    await restoreResult.fold(
      (failure) async {
        if (validationEpoch != _authEpoch) {
          return;
        }
        print('✗ Session restore error: ${failure.message}');
        await handleSessionExpired();
      },
      (sessionRestored) async {
        if (validationEpoch != _authEpoch) {
          return;
        }
        if (!sessionRestored) {
          await handleSessionExpired();
          return;
        }

        final userResult = await apiService.getCurrentUser().run();
        if (validationEpoch != _authEpoch) {
          return;
        }
        await userResult.fold(
          (failure) async {
            if (validationEpoch != _authEpoch) {
              return;
            }
            print('✗ Failed to get current user: ${failure.message}');
            await handleSessionExpired();
          },
          (user) async {
            if (validationEpoch != _authEpoch) {
              return;
            }
            _currentUser = user;
            _isAuthenticated = true;
            notifyListeners();
            print('✓ Session restored, user: ${_currentUser?.username}');

            final fcmSynced = await notificationService.syncToken();
            if (!fcmSynced) {
              await handleSessionExpired();
            }
          },
        );
      },
    );
  }

  /// Register new user
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    _isAuthenticating = true;
    _error = null;
    _authEpoch++;
    notifyListeners();

    try {
      final result = await apiService
          .register(
            username: username,
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
          )
          .run();

      return result.fold(
        (failure) {
          _error = failure.message;
          _isAuthenticating = false;
          notifyListeners();
          print('✗ Registration failed: ${failure.message}');
          return false;
        },
        (authResponse) {
          _currentUser = authResponse.user;
          _isAuthenticated = true;
          _isNewUser = true; // Mark as new user for routing
          _isAuthenticating = false;
          notifyListeners();
          print('✓ Registration successful');
          return true;
        },
      );
    } catch (error) {
      _error = error.toString().replaceAll('Exception: ', '');
      _isAuthenticating = false;
      notifyListeners();
      print('✗ Registration threw an exception: $error');
      return false;
    }
  }

  /// Login user
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isAuthenticating = true;
    _error = null;
    _authEpoch++;
    notifyListeners(); //it trigers the loading indicator

    try {
      final result = await apiService
          .login(
            username: username,
            password: password,
          )
          .run();

      return result.fold(
        (failure) {
          _error = failure.message;
          _isAuthenticating = false;
          notifyListeners();
          print('✗ Login failed: ${failure.message}');
          return false;
        },
        (authResponse) async {
          _currentUser = authResponse.user;
          _isAuthenticated = true;
          _isAuthenticating = false;
          notifyListeners();

          // Sync FCM token in the background so auth success is not blocked by
          // notification setup or transient network issues.
          unawaited(notificationService.syncToken());

          print('✓ Login successful');
          return true;
        },
      );
    } catch (error) {
      _error = error.toString().replaceAll('Exception: ', '');
      _isAuthenticating = false;
      notifyListeners();
      print('✗ Login threw an exception: $error');
      return false;
    }
  }

  /// Clear auth state immediately (for instant UI updates)
  void clearAuth() {
    _currentUser = null;
    _isAuthenticated = false;
    _isNewUser = false;
    notifyListeners();
    print('✓ Auth state cleared');
  }

  /// Mark new user as onboarded (stops redirecting to suggested friends)
  void completeOnboarding() {
    _isNewUser = false;
    notifyListeners();
  }

  /// Logout user - clears state and navigates immediately, backend cleanup in background
  Future<void> logout() async {
    final logoutEpoch = ++_authEpoch;
    final scopedUserId = apiService.tokenStorage.getCurrentUserId();
    final refreshToken = apiService.tokenStorage.getRefreshToken();

    try {
      await apiService.forceLogout();
    } catch (error) {
      print('⚠ Local logout cleanup failed: $error');
    }

    if (logoutEpoch != _authEpoch) {
      return;
    }

    clearAuth();

    if (scopedUserId != null) {
      unawaited(_clearScopedLocalData(scopedUserId));
    }

    _logoutBackground(refreshToken: refreshToken);
  }

  Future<void> _clearScopedLocalData(String userId) async {
    await Future.wait([
      FriendPersistenceService().clearFriendsForUser(userId),
      ChatController(apiService: apiService).clearCachedRoomsForUser(userId),
      ChatPersistenceService().clearMessagesForUser(userId),
    ]);
  }

  /// Background logout - handle backend logout and token cleanup without blocking UI
  void _logoutBackground({String? refreshToken}) {
    // Fire and forget - don't block on these operations
    Future.microtask(() async {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await apiService.dio.post(
            ApiConstant.logout,
            data: {'refresh': refreshToken},
          );
          print('✓ Backend logout successful');
        } catch (error) {
          print('✗ Backend logout failed: $error');
        }
      } else {
        final result = await apiService.logout().run();
        result.fold(
          (failure) => print('✗ Backend logout failed: ${failure.message}'),
          (_) => print('✓ Backend logout successful'),
        );
      }

      try {
        await notificationService.deleteToken();
        print('✓ FCM token cleanup done');
      } catch (e) {
        print('✗ FCM cleanup failed: $e');
      }
    });
  }

  /// Force a logout when the session is no longer valid.
  Future<void> handleSessionExpired() async {
    _authEpoch++;
    final scopedUserId = apiService.tokenStorage.getCurrentUserId();

    try {
      await apiService.forceLogout();
    } catch (error) {
      print('⚠ Session cleanup failed: $error');
    }

    if (scopedUserId != null) {
      unawaited(_clearScopedLocalData(scopedUserId));
    }

    clearAuth();
    _error = 'Session expired. Please log in again.';
    notifyListeners();

    print('✓ Session expired - user logged out');
  }

  /// Change password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService
        .changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
          newPasswordConfirm: newPasswordConfirm,
        )
        .run();

    return result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Change password failed: ${failure.message}');
        return false;
      },
      (_) {
        _isLoading = false;
        notifyListeners();
        print('✓ Password changed successfully');
        return true;
      },
    );
  }

  /// Delete user account
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService.deleteUserAccount().run();

    return result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Account deletion failed: ${failure.message}');
        return false;
      },
      (_) {
        _currentUser = null;
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        print('✓ Account deleted successfully');
        return true;
      },
    );
  }

  /// Refresh current user data
  Future<void> refreshUserData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService.getCurrentUser().run();

    result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to refresh user data: ${failure.message}');
      },
      (user) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        print('✓ User data refreshed');
      },
    );
  }
}
