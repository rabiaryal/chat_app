import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

      // 2. Request permissions (iOS/macOS only)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✓ User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('✓ User granted provisional notification permission');
      } else {
        print('✗ User declined or has not accepted notification permission');
      }

      // 3. Set background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // 4. Handle foreground messages
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

      // 5. Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        // Navigate to the specific chat room if data contains room_id
      });

      _isInitialized = true;

      // Initial token sync
      await syncToken();
    } catch (e) {
      print('✗ NotificationService initialization error: $e');
    }
  }

  /// Sync FCM token with backend
  Future<bool> syncToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('✓ FCM Token: $token');

        String platform = 'web';
        if (!kIsWeb) {
          if (Platform.isAndroid) platform = 'android';
          if (Platform.isIOS) platform = 'ios';
          if (Platform.isMacOS) platform = 'macos';
        }

        await apiService.registerDevice(token, platform);
        return true;
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

  /// Delete FCM token (e.g., on logout)
  Future<void> deleteToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await apiService.unregisterDevice(token);
        await FirebaseMessaging.instance.deleteToken();
        print('✓ FCM Token deleted and unregistered');
      }
    } catch (e) {
      print('✗ FCM Token deletion error: $e');
    }
  }
}
