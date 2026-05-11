import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../models/chat_room.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/dashboard/chat_card.dart';
import '../widgets/dashboard/chat_app_bar.dart';
import '../widgets/dashboard/dashboard_bottom_nav.dart';
import '../widgets/chat_bubble.dart';
import '../providers/auth_provider.dart';
import 'suggested_friends_screen.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _selectedTabIndex = 0;
  int _selectedBottomIndex = 0;
  String _searchQuery = '';
  User? _currentUser;
  bool _isLoading = true;
  int? _userId;
  String _username = '';
  bool _isLoggingOut = false; // Prevent double-tap logout

  @override
  void initState() {
    super.initState();
    // Use microtask to avoid "setState during build" error
    Future.microtask(() {
      if (!mounted) return;
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final apiService = ApiService();

    try {
      await roomProvider.loadRooms();
      // Ensure friends are loaded so the horizontal list shows immediately
      friendProvider.loadAllFriendsData();
      final user = await apiService.getCurrentUser();
      if (!mounted) return;
      roomProvider.setCurrentUserId(user.id);
      setState(() {
        _currentUser = user;
        _userId = user.id;
        _username = user.username;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      print('✗ Failed to load data: $e');
    }
  }

  void _logout() {
    // Prevent double-tap logout
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 1. Clear auth state immediately
    authProvider.clearAuth();

    // 2. Navigate to login instantly (no await)
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    }

    // 3. Handle cleanup in background (fire and forget)
    authProvider.logoutBackground();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: ChatAppBar(
        primaryColor: primaryColor,
        currentUser: _currentUser,
        onLogout: _logout,
      ),
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: _selectedBottomIndex,
        primaryColor: primaryColor,
        currentUser: _currentUser,
        onItemSelected: (index) => setState(() => _selectedBottomIndex = index),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  Provider.of<RoomProvider>(context, listen: false).loadRooms(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    _buildHorizontalList(primaryColor),
                    _buildTabs(primaryColor),
                    _buildChatList(primaryColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHorizontalList(Color primaryColor) {
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, _) {
        final friends = friendProvider.friends;

        return Container(
          height: 110,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: friends.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // New Group Button
                return Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CreateGroupScreen()),
                        ),
                        child: Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.add, color: primaryColor, size: 30),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('New',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final friend = friends[index - 1];

              return Padding(
                padding: const EdgeInsets.only(right: 15),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final roomProvider =
                            Provider.of<RoomProvider>(context, listen: false);
                        final chatProvider =
                            Provider.of<ChatProvider>(context, listen: false);

                        try {
                          // Get or create DM room with this friend
                          final room = await context
                              .read<ApiService>()
                              .getOrCreateDirectRoom(friend.id);

                          if (!mounted) return;

                          // Validate room data
                          if (room.id.isEmpty) {
                            throw Exception('Invalid room ID from server');
                          }

                          // Navigate to chat
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChangeNotifierProvider.value(
                                value: chatProvider,
                                child: ChatScreen(
                                  roomId: room.id,
                                  roomName: friend.displayName,
                                  userId: _userId ?? 0,
                                  username:
                                      _username.isNotEmpty ? _username : 'User',
                                  friendId: friend.id,
                                  isGroup: false,
                                ),
                              ),
                            ),
                          );

                          // Add room to provider if it's new
                          if (!roomProvider.rooms.any((r) => r.id == room.id)) {
                            roomProvider.addRoom(room);
                          }
                        } catch (e) {
                          if (mounted) {
                            print('✗ Chat error: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Failed to start chat: ${e.toString()}')),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: friend.avatar != null
                                  ? Image.network(friend.avatar!,
                                      fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        friend.displayName.trim().isNotEmpty
                                            ? friend.displayName
                                                .trim()[0]
                                                .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                            ),
                            // Online indicator
                            if (friend.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 65,
                      child: Text(
                        friend.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTabs(Color primaryColor) {
    final tabs = ['All', 'Unread', 'Groups', 'Favorites'];
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey[200]!),
              ),
              child: Center(
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search chats...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(Color primaryColor) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, _) {
        List<ChatRoom> rooms = roomProvider.rooms;

        // Apply tab filtering
        if (_selectedTabIndex == 1) {
          // Unread
          rooms = rooms.where((r) => r.unreadCount > 0).toList();
        } else if (_selectedTabIndex == 2) {
          // Groups
          rooms = rooms.where((r) => r.roomType == 'GROUP').toList();
        } else if (_selectedTabIndex == 3) {
          // Favorites
          rooms = []; // Not implemented yet
        }

        if (_searchQuery.isNotEmpty) {
          rooms = rooms
              .where((r) =>
                  r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
        }

        if (rooms.isEmpty) {
          String emptyTitle = "You haven't any friends as of now";
          String emptySubtitle =
              "Add more people to chat and start sharing your moments!";
          bool showActionButton = true;

          if (_selectedTabIndex == 1) {
            // Unread
            emptyTitle = "You have read all of your messages";
            emptySubtitle = "Keep up the good work! You're all caught up.";
            showActionButton = false;
          } else if (_selectedTabIndex == 3) {
            // Favorites
            emptyTitle = "You have no favourites as of now";
            emptySubtitle = "Star your favorite people to see them here first.";
            showActionButton = false;
          }

          return Padding(
            padding: const EdgeInsets.only(top: 100),
            child: EmptyChat(
              title: emptyTitle,
              subtitle: emptySubtitle,
              actionLabel: showActionButton ? "Find People" : null,
              onAction: showActionButton
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SuggestedFriendsScreen()),
                      );
                    }
                  : null,
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            return ChatCard(
              room: rooms[index],
              primaryColor: primaryColor,
              currentUserId: _userId,
              currentUsername: _username,
            );
          },
        );
      },
    );
  }
}
