import 'dart:async';

import 'package:chat_app/constants/api_constant.dart';
import 'package:chat_app/providers/app_dependencies.dart';
import 'package:chat_app/services/api_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/notification_service.dart';
import '../../../services/realtime/chat_controller.dart';
import '../../../services/storage/chat_persistence_service.dart';
import '../../../services/storage/friend_persistence_service.dart';
import '../models/user.dart';

class AuthState extends Equatable {
  static const Object _unset = Object();

  final User? currentUser;
  final bool isLoading;
  final bool isAuthenticating;
  final String? error;
  final bool isAuthenticated;
  final bool isNewUser;

  const AuthState({
    required this.currentUser,
    required this.isLoading,
    required this.isAuthenticating,
    required this.error,
    required this.isAuthenticated,
    required this.isNewUser,
  });

  factory AuthState.initial() => const AuthState(
        currentUser: null,
        isLoading: false,
        isAuthenticating: false,
        error: null,
        isAuthenticated: false,
        isNewUser: false,
      );

  AuthState copyWith({
    Object? currentUser = _unset,
    Object? isLoading = _unset,
    Object? isAuthenticating = _unset,
    Object? error = _unset,
    Object? isAuthenticated = _unset,
    Object? isNewUser = _unset,
  }) {
    return AuthState(
      currentUser: identical(currentUser, _unset)
          ? this.currentUser
          : currentUser as User?,
      isLoading:
          identical(isLoading, _unset) ? this.isLoading : isLoading as bool,
      isAuthenticating: identical(isAuthenticating, _unset)
          ? this.isAuthenticating
          : isAuthenticating as bool,
      error: identical(error, _unset) ? this.error : error as String?,
      isAuthenticated: identical(isAuthenticated, _unset)
          ? this.isAuthenticated
          : isAuthenticated as bool,
      isNewUser:
          identical(isNewUser, _unset) ? this.isNewUser : isNewUser as bool,
    );
  }

  @override
  List<Object?> get props => [
        currentUser,
        isLoading,
        isAuthenticating,
        error,
        isAuthenticated,
        isNewUser,
      ];
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService apiService;
  final NotificationService notificationService;
  int _authEpoch = 0;

  AuthNotifier({
    required this.apiService,
    required this.notificationService,
  }) : super(AuthState.initial()) {
    notificationService.setSessionExpiredCallback(handleSessionExpired);
    apiService.setSessionExpiredCallback(handleSessionExpired);
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);

    final hasLocalSession = apiService.tokenStorage.hasAccessToken();
    state = state.copyWith(
      isAuthenticated: hasLocalSession,
      isLoading: false,
      currentUser: hasLocalSession ? state.currentUser : null,
      isNewUser: hasLocalSession ? state.isNewUser : false,
      error: null,
    );

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
            state = state.copyWith(
              currentUser: user,
              isAuthenticated: true,
              isLoading: false,
              error: null,
            );
            print('✓ Session restored, user: ${state.currentUser?.username}');

            unawaited(notificationService.initialize());
            final fcmSynced = await notificationService.syncToken();
            if (!fcmSynced) {
              await handleSessionExpired();
            }
          },
        );
      },
    );
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    state = state.copyWith(isAuthenticating: true, error: null);
    _authEpoch++;

    try {
      final result = await apiService
          .register(
            username: username,
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            persistSession: true,
          )
          .run();

      return result.fold(
        (failure) {
          state = state.copyWith(
            isAuthenticating: false,
            error: failure.message,
          );
          print('✗ Registration failed: ${failure.message}');
          return false;
        },
        (authResponse) {
          state = state.copyWith(
            currentUser: authResponse.user,
            isAuthenticated: true,
            isNewUser: true,
            isAuthenticating: false,
            error: null,
          );
          unawaited(notificationService.initialize());
          print('✓ Registration successful');
          return true;
        },
      );
    } catch (error) {
      state = state.copyWith(
        isAuthenticating: false,
        error: error.toString().replaceAll('Exception: ', ''),
      );
      print('✗ Registration threw an exception: $error');
      return false;
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    state = state.copyWith(isAuthenticating: true, error: null);
    _authEpoch++;

    try {
      final result = await apiService
          .login(
            username: username,
            password: password,
            persistSession: rememberMe,
          )
          .run();

      return result.fold(
        (failure) {
          state = state.copyWith(
            isAuthenticating: false,
            error: failure.message,
          );
          print('✗ Login failed: ${failure.message}');
          return false;
        },
        (authResponse) {
          state = state.copyWith(
            currentUser: authResponse.user,
            isAuthenticated: true,
            isNewUser: false,
            isAuthenticating: false,
            error: null,
          );

          unawaited(notificationService.initialize());
          unawaited(notificationService.syncToken());

          print('✓ Login successful');
          return true;
        },
      );
    } catch (error) {
      state = state.copyWith(
        isAuthenticating: false,
        error: error.toString().replaceAll('Exception: ', ''),
      );
      print('✗ Login threw an exception: $error');
      return false;
    }
  }

  void clearAuth() {
    state = state.copyWith(
      currentUser: null,
      isAuthenticated: false,
      isNewUser: false,
      error: null,
    );
    print('✓ Auth state cleared');
  }

  void completeOnboarding() {
    state = state.copyWith(isNewUser: false);
  }

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

  void _logoutBackground({String? refreshToken}) {
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
    state = state.copyWith(error: 'Session expired. Please log in again.');

    print('✓ Session expired - user logged out');
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await apiService
        .changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
          newPasswordConfirm: newPasswordConfirm,
        )
        .run();

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        print('✗ Change password failed: ${failure.message}');
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, error: null);
        print('✓ Password changed successfully');
        return true;
      },
    );
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await apiService.deleteUserAccount().run();

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        print('✗ Account deletion failed: ${failure.message}');
        return false;
      },
      (_) {
        state = state.copyWith(
          currentUser: null,
          isAuthenticated: false,
          isNewUser: false,
          isLoading: false,
          error: null,
        );
        print('✓ Account deleted successfully');
        return true;
      },
    );
  }

  Future<void> refreshUserData() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await apiService.getCurrentUser().run();

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        print('✗ Failed to refresh user data: ${failure.message}');
      },
      (user) {
        state =
            state.copyWith(currentUser: user, isLoading: false, error: null);
        print('✓ User data refreshed');
      },
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    apiService: ref.read(apiServiceProvider),
    notificationService: ref.read(notificationServiceProvider),
  );
});
