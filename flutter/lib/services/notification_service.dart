import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized (required for background)
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  // Logic for E2EE: The app could trigger a local notification here
  // or wait for the user to open the app and fetch the message via WebSocket/API.
}

class NotificationService {
  final ApiService apiService;
  Future<void> Function()? _onSessionExpired;
  bool _isInitialized = false;

  static const String _notificationsEnabledKey = 'notifications_enabled';

  NotificationService({required this.apiService});

  void setSessionExpiredCallback(Future<void> Function() callback) {
    _onSessionExpired = callback;
  }

  /// Initialize FCM
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase Messaging
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      final notificationsEnabled = await isNotificationsEnabled();

      await messaging.setAutoInitEnabled(notificationsEnabled);

      // Keep the core handlers active regardless of the preference so the app
      // can still react to messages and the user can re-enable later.

      // 2. Set background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // 3. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');
        }

        // Note: For E2EE, we mostly care about message.data['event'] == 'new_message'
        // which should trigger a UI update or a local notification.
      });

      // 4. Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        // Navigate to the specific chat room if data contains room_id
      });

      // 5. Keep backend token mapping fresh after FCM rotates device token
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        if (!await isNotificationsEnabled()) {
          return;
        }
        try {
          final platform = _backendDeviceType();
          await apiService.registerDevice(newToken, platform).run();
          print('✓ Refreshed FCM token synced');
        } catch (e) {
          print('✗ Refreshed FCM token sync error: $e');
        }
      });

      _isInitialized = true;

      if (!notificationsEnabled) {
        return;
      }

      // Request permissions only when notifications are enabled locally.
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabledKey, granted);

      if (granted) {
        print('✓ User granted notification permission');
        // Initial token sync
        await syncToken();
      } else {
        await messaging.setAutoInitEnabled(false);
        print('✗ User declined or has not accepted notification permission');
      }
    } catch (e) {
      print('✗ NotificationService initialization error: $e');
    }
  }

  /// Read the local push-notification preference.
  Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  /// Enable or disable push notifications from the profile screen.
  Future<bool> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final messaging = FirebaseMessaging.instance;

    if (!enabled) {
      await prefs.setBool(_notificationsEnabledKey, false);
      await messaging.setAutoInitEnabled(false);
      await deleteToken();
      return false;
    }

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    await prefs.setBool(_notificationsEnabledKey, granted);
    await messaging.setAutoInitEnabled(granted);

    if (!granted) {
      print('✗ Notification permission was not granted');
      return false;
    }

    final synced = await syncToken();
    return synced || granted;
  }

  /// Sync FCM token with backend
  Future<bool> syncToken() async {
    try {
      if (!await isNotificationsEnabled()) {
        return false;
      }

      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('✓ FCM Token: $token');

        final platform = _backendDeviceType();

        final result = await apiService.registerDevice(token, platform).run();
        return result.fold(
          (failure) {
            print('✗ FCM token sync error: ${failure.message}');
            return false;
          },
          (_) => true,
        );
      }
      return true;
    } on SessionExpiredException catch (e) {
      print('✗ FCM token sync detected expired session: $e');
      await _onSessionExpired?.call();
      return false;
    } catch (e) {
      print('✗ FCM Token sync error: $e');
      return false;
    }
  }

  /// Backend accepts android/ios/web; map Apple desktop to ios/APNs path.
  String _backendDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS || Platform.isMacOS) return 'ios';
    return 'web';
  }

  /// Delete FCM token (e.g., on logout)
  Future<void> deleteToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final result = await apiService.unregisterDevice(token).run();
        result.fold(
          (failure) =>
              print('✗ FCM token unregister failed: ${failure.message}'),
          (_) => print('✓ FCM token unregistered from backend'),
        );
        await FirebaseMessaging.instance.deleteToken();
        print('✓ FCM Token deleted and unregistered');
      }
    } catch (e) {
      print('✗ FCM Token deletion error: $e');
    }
  }
}
