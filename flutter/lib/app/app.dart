import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as pprovider;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/router.dart';
import '../features/auth/provider/auth_provider.dart';
import '../providers/app_dependencies.dart';
import '../providers/friend_provider.dart';
import '../providers/presence_provider.dart';
import '../services/realtime/presence_service.dart';
import '../services/realtime/socket_service.dart';
import 'bootstrap.dart';
import 'legacy_providers.dart';

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<BootstrapDependencies> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapDependencies>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoadingSplashScreen(),
          );
        }

        final deps = snapshot.data!;
        return ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(deps.apiService),
            notificationServiceProvider.overrideWithValue(
              deps.notificationService,
            ),
          ],
          child: ChatApp(deps: deps),
        );
      },
    );
  }
}

class ChatApp extends ConsumerStatefulWidget {
  final BootstrapDependencies deps;

  const ChatApp({super.key, required this.deps});

  @override
  ConsumerState<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends ConsumerState<ChatApp> {
  bool _startupReady = false;
  bool _presenceListenerAttached = false;
  late final PresenceSocketService _presenceService;
  StreamSubscription? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _presenceService =
        PresenceSocketService(apiService: widget.deps.apiService);
    unawaited(_prepareStartup());
  }

  Future<void> _prepareStartup() async {
    await widget.deps.tokenStorage.initialize();

    final authNotifier = ref.read(authProvider.notifier);
    authNotifier.initialize();
    SocketService(apiService: widget.deps.apiService).setUnauthorizedHandler(
      authNotifier.handleSessionExpired,
    );

    if (!mounted) return;

    setState(() {
      _startupReady = true;
    });
  }

  @override
  void dispose() {
    unawaited(_presenceService.disconnect());
    _presenceSubscription?.cancel();
    widget.deps.chatService.dispose();
    widget.deps.tokenStorage.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_presenceListenerAttached) {
      _presenceListenerAttached = true;
      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated && next.currentUser != null) {
          unawaited(_presenceService.connect());
        } else {
          unawaited(_presenceService.disconnect());
          // clear presence on logout
          ref.read(presenceProvider.notifier).clear();
        }
      });

      _presenceSubscription = _presenceService.onPresence.listen((msg) {
        final type = msg['type'] as String?;
        final payload = msg['payload'] as Map<String, dynamic>?;
        if (type == 'presence_delta' && payload != null) {
          final userIdRaw = payload['user_id'];
          final isOnline = payload['is_online'] == true;
          final userId = userIdRaw is int
              ? userIdRaw
              : int.tryParse(userIdRaw?.toString() ?? '');
          if (userId == null) return;

          final presenceNotifier = ref.read(presenceProvider.notifier);
          if (isOnline) {
            presenceNotifier.setOnline(userId);
          } else {
            presenceNotifier.setOffline(userId);
          }
        }
      });
    }

    if (!_startupReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoadingSplashScreen(),
      );
    }

    return LegacyProviders(
      apiService: widget.deps.apiService,
      chatService: widget.deps.chatService,
      notificationService: widget.deps.notificationService,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp.router(
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
            routerConfig: ref.read(appRouterProvider),
            scaffoldMessengerKey: MyApp.messengerKey,
          );
        },
      ),
    );
  }
}

class MyApp {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
}
