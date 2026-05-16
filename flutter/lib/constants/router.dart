import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/storage/hive_token_storage.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/create_group_screen.dart';
import '../screens/chat/friend_profile_screen.dart';
import '../screens/chat/friends_list_screen.dart';
import '../screens/chat/user_profile_screen.dart';
import '../screens/splash/first_time_splash.dart';
import '../screens/splash/suggested_friends_screen.dart';
import '../models/user.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isNewUser = authProvider.isNewUser;
        final hasLocalSession = HiveTokenStorage.instance.hasAccessToken();

        final isAuthPath = state.matchedLocation == '/auth';
        final isSplashPath = state.matchedLocation == '/';
        final isFirstTimePath = state.matchedLocation == '/first-time';

        if (hasLocalSession || isAuthenticated) {
          if (isAuthPath || isFirstTimePath || isSplashPath) {
            return isNewUser ? '/suggested-friends' : '/chat-list';
          }
          return null;
        }

        if (!isAuthPath && !isSplashPath && !isFirstTimePath) {
          return '/auth';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreenWrapper(),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => AuthScreen(),
        ),
        GoRoute(
          path: '/first-time',
          builder: (context, state) => const FirstTimeSplashScreen(),
        ),
        GoRoute(
          path: '/chat-list',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/suggested-friends',
          builder: (context, state) => const SuggestedFriendsScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) {
            final extras = state.extra as Map<String, dynamic>;
            return ChatScreen(
              roomId: extras['roomId'] as String,
              roomName: extras['roomName'] as String,
              userId: extras['userId'] as int,
              username: extras['username'] as String,
              friendId: extras['friendId'] as int,
              isGroup: extras['isGroup'] as bool? ?? false,
            );
          },
        ),
        GoRoute(
          path: '/create-group',
          builder: (context, state) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: '/friends-list',
          builder: (context, state) => FriendsListScreen(),
        ),
        GoRoute(
          path: '/friend-profile',
          builder: (context, state) {
            final extras = state.extra as Map<String, dynamic>;
            return FriendProfileScreen(
              userId: extras['userId'] as int,
              username: extras['username'] as String,
              avatar: extras['avatar'] as String?,
              bio: extras['bio'] as String?,
            );
          },
        ),
        GoRoute(
          path: '/user-profile',
          builder: (context, state) {
            final extras = state.extra as Map<String, dynamic>;
            return UserProfileScreen(
              user: extras['user'] as User,
              isCurrentUser: extras['isCurrentUser'] as bool? ?? false,
            );
          },
        ),
      ],
    );
  }
}

/// A wrapper for the loading splash screen that redirects based on auth state
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({Key? key}) : super(key: key);

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _didRedirect = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectNow();
    });
  }

  void _redirectNow() {
    if (!mounted || _didRedirect) {
      return;
    }

    _didRedirect = true;
    final hasLocalSession = HiveTokenStorage.instance.hasAccessToken();
    context.go(hasLocalSession ? '/chat-list' : '/auth');
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingSplashScreen();
  }
}

/// The actual splash screen UI (to be moved from main.dart or kept here)
class LoadingSplashScreen extends StatelessWidget {
  const LoadingSplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chat App',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Opening your chats...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
