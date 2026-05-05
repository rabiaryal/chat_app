/// Auth State Management using Provider
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService apiService;

  User? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticating = false;
  String? _error;
  bool _isAuthenticated = false;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticating => _isAuthenticating;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider({required this.apiService});

  /// Initialize auth state - restore session if available
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to restore session from secure storage
      final sessionRestored = await apiService.restoreSession();
      if (sessionRestored) {
        // Get current user data
        _currentUser = await apiService.getCurrentUser();
        _isAuthenticated = true;
        print('✓ Session restored, user: ${_currentUser?.username}');
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      print('✗ Session restore error: $e');
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    notifyListeners();

    try {
      final authResponse = await apiService.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      _currentUser = User.fromJson(authResponse.user);
      _isAuthenticated = true;
      _isAuthenticating = false;
      notifyListeners();
      print('✓ Registration successful');
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticating = false;
      notifyListeners();
      print('✗ Registration failed: $e');
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
    notifyListeners();

    try {
      final authResponse = await apiService.login(
        username: username,
        password: password,
      );
      _currentUser = User.fromJson(authResponse.user);
      _isAuthenticated = true;
      _isAuthenticating = false;
      notifyListeners();
      print('✓ Login successful');
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticating = false;
      notifyListeners();
      print('✗ Login failed: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.logout();
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      print('✓ Logout successful');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Logout failed: $e');
    }
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

    try {
      await apiService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        newPasswordConfirm: newPasswordConfirm,
      );
      _isLoading = false;
      notifyListeners();
      print('✓ Password changed successfully');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Change password failed: $e');
      return false;
    }
  }

  /// Delete user account
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.deleteUserAccount();
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      print('✓ Account deleted successfully');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Account deletion failed: $e');
      return false;
    }
  }

  /// Refresh current user data
  Future<void> refreshUserData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await apiService.getCurrentUser();
      _isLoading = false;
      notifyListeners();
      print('✓ User data refreshed');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to refresh user data: $e');
    }
  }
}
