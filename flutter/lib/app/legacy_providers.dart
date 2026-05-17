import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/room_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/realtime/chat_service.dart';

class LegacyProviders extends StatelessWidget {
  final ApiService apiService;
  final ChatService chatService;
  final NotificationService notificationService;
  final Widget child;

  const LegacyProviders({
    super.key,
    required this.apiService,
    required this.chatService,
    required this.notificationService,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<ChatService>.value(value: chatService),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider(
          create: (_) => RoomProvider(
            apiService: apiService,
            chatService: chatService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(chatService: chatService),
        ),
        ChangeNotifierProvider(
          create: (_) => FriendProvider(apiService: apiService),
        ),
      ],
      child: child,
    );
  }
}
