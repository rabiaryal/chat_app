/// Main Flutter App - Chat Application
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/chat_service.dart';
import 'services/hive_token_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';

void main() async {
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
  bool _isChecking = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(tokenStorage: widget.tokenStorage);
    _chatService = ChatService(apiService: _apiService);
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final restored = await _chatService.restoreSession();
      if (restored) {
        // Ensure E2EE keys are set up
        await _chatService.setupE2EE();
      }
      setState(() {
        _isAuthenticated = restored;
        _isChecking = false;
      });
    } catch (e) {
      print('Authentication error: $e');
      setState(() {
        _isAuthenticated = false;
        _isChecking = false;
      });
    }
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
          create: (_) => AuthProvider(apiService: _apiService),
        ),
        // Room Provider for room management
        ChangeNotifierProvider(
          create: (_) => RoomProvider(apiService: _apiService),
        ),
        // Chat Provider for real-time chat (depends on ChatService)
        ChangeNotifierProvider(
          create: (_) => ChatProvider(chatService: _chatService),
        ),
        // Friend Provider for friend management
        ChangeNotifierProvider(
          create: (_) => FriendProvider(apiService: _apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Chat App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
    
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        darkTheme: ThemeData.dark(
          useMaterial3: true,
        ),
        themeMode: ThemeMode.light,
        home: _isChecking
            ? const SplashScreen()
            : (_isAuthenticated ? ChatListScreen() : AuthScreen()),
        routes: {
          '/auth': (context) => AuthScreen(),
          '/chat-list': (context) => ChatListScreen(),
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
