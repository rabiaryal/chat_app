import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/chat_service.dart';
import 'services/hive_token_storage.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/first_time_splash.dart';
import 'screens/suggested_friends_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Requires google-services.json / GoogleService-Info.plist)
  try {
    await Firebase.initializeApp();
    print('✓ Firebase initialized');
  } catch (e) {
    print('⚠ Firebase initialization failed: $e');
    print(
        'Note: You need to add google-services.json (Android) or GoogleService-Info.plist (iOS) to your project.');
  }

  // Initialize Hive for token storage
  final tokenStorage = HiveTokenStorage();
  await tokenStorage.initialize();
  runApp(MyApp(tokenStorage: tokenStorage));
}

class MyApp extends StatefulWidget {
  final HiveTokenStorage tokenStorage;

  const MyApp({
    Key? key,
    required this.tokenStorage,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ApiService _apiService;
  late final ChatService _chatService;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(tokenStorage: widget.tokenStorage);
    _chatService = ChatService(apiService: _apiService);
    _notificationService = NotificationService(apiService: _apiService);

    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
  }

  @override
  void dispose() {
    _chatService.dispose();
    widget.tokenStorage.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // API Service (required by others)
        Provider<ApiService>(
          create: (_) => _apiService,
        ),
        // Chat Service (required by ChatProvider)
        Provider<ChatService>(
          create: (_) => _chatService,
        ),
        // Auth Provider for authentication state management
        ChangeNotifierProvider(
          create: (_) {
            final authProvider = AuthProvider(
              apiService: _apiService,
              notificationService: _notificationService,
            );
            Future.microtask(authProvider.initialize);
            return authProvider;
          },
        ),
        // Room Provider for room management
        ChangeNotifierProvider(
          create: (_) => RoomProvider(
            apiService: _apiService,
            chatService: _chatService,
          ),
        ),
        // Chat Provider for real-time chat (depends on ChatService)
        ChangeNotifierProvider(
          create: (_) => ChatProvider(chatService: _chatService),
        ),
        // Notification Service
        Provider<NotificationService>(
          create: (_) => _notificationService,
        ),
        // Friend Provider for friend management
        ChangeNotifierProvider(
          create: (_) => FriendProvider(apiService: _apiService),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'Chat App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: const Color(0xFF6C5CE7),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6C5CE7),
                primary: const Color(0xFF6C5CE7),
                secondary: const Color(0xFFA29BFE),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.grey[50],
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
              ),
            ),
            darkTheme: ThemeData.dark(
              useMaterial3: true,
            ),
            themeMode: ThemeMode.light,
            home: authProvider.isLoading
                ? const SplashScreen()
                : (authProvider.isAuthenticated
                    ? ChatListScreen()
                    : const FirstTimeSplashScreen()),
            routes: {
              '/auth': (context) => AuthScreen(),
              '/first-time': (context) => const FirstTimeSplashScreen(),
              '/chat-list': (context) => ChatListScreen(),
              '/suggested-friends': (context) => const SuggestedFriendsScreen(),
            },
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 24),
            Text(
              'Chat App',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
