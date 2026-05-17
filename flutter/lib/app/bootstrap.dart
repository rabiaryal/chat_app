import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/realtime/chat_service.dart';
import '../services/storage/hive_token_storage.dart';

class BootstrapDependencies {
  final HiveTokenStorage tokenStorage;
  final ApiService apiService;
  final ChatService chatService;
  final NotificationService notificationService;

  BootstrapDependencies({
    required this.tokenStorage,
    required this.apiService,
    required this.chatService,
    required this.notificationService,
  });
}

Future<BootstrapDependencies> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('✓ Firebase initialized');
  } catch (error) {
    print('⚠ Firebase initialization failed: $error');
    print(
      'Note: You need to add google-services.json (Android) or GoogleService-Info.plist (iOS) to your project.',
    );
  }

  await Hive.initFlutter();

  final tokenStorage = HiveTokenStorage();
  final apiService = ApiService(tokenStorage: tokenStorage);
  final notificationService = NotificationService(apiService: apiService);
  final chatService = ChatService(apiService: apiService);

  return BootstrapDependencies(
    tokenStorage: tokenStorage,
    apiService: apiService,
    chatService: chatService,
    notificationService: notificationService,
  );
}
