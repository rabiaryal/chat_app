/// Chat List Screen - Friends Centered
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/chat_controller.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/room_provider.dart';
import '../models/user.dart';
import '../models/friend.dart';
import '../models/chat_room.dart';
import 'chat_screen.dart';
import 'friends_list_screen.dart';
import 'user_profile_screen.dart';
import 'create_group_screen.dart';
import '../widgets/add_friend_bottom_sheet.dart';

class ChatListScreen extends StatefulWidget {
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late ApiService _apiService;
  late ChatController _chatController;
  int? _userId;
  String _username = '';
  User? _currentUser;
  bool _isLoading = false;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _chatController = ChatController(apiService: _apiService);
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!mounted) return;
        final friendProvider = Provider.of<FriendProvider>(context, listen: false);
        if (!friendProvider.isLoadingMore && friendProvider.hasMoreFriends && _searchQuery.isEmpty) {
          friendProvider.loadFriends(refresh: false);
        }
      }
    });
    
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    setState(() => _isLoading = true);

    try {
      // First, restore the session
      print('📱 Restoring session from secure storage...');
      final sessionRestored = await _apiService.restoreSession();

      if (!sessionRestored) {
        print('✗ Failed to restore session - no valid tokens found');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
        return;
      }

      print('✓ Session restored, loading user data...');
      // Then load user data and friends
      if (mounted) {
        await _loadUserData();
      }
    } catch (e) {
      print('✗ Session restore error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session error: $e')),
        );
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
      }
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Get current user info
      final user = await _apiService.getCurrentUser();
      _userId = user.id;
      _username = user.username;
      _currentUser = user;

      // Load data using Providers
      if (mounted) {
        await Future.wait([
          Provider.of<FriendProvider>(context, listen: false).loadFriends(refresh: true),
          Provider.of<RoomProvider>(context, listen: false).loadRooms(),
        ]);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (mounted) {
      await Future.wait([
        Provider.of<FriendProvider>(context, listen: false).loadFriends(refresh: true),
        Provider.of<RoomProvider>(context, listen: false).loadRooms(),
      ]);
    }
  }

  Future<void> _logout() async {
    try {
      // Perform API logout
      await _apiService.logout();
    } catch (e) {
      print('Logout error: $e');
    }

    // Navigate to auth screen (pushReplacementNamed clears entire stack)
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  Future<void> _startChat(int friendId, String friendName) async {
    if (_userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User data is still loading...')),
        );
      }
      return;
    }

    try {
      final response =
          await _chatController.initializeChat(targetUserId: friendId);

      if (!mounted) return;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: chatProvider,
              child: ChatScreen(
                roomId: response.roomId,
                roomName: response.roomName,
                userId: _userId!,
                username: friendName,
                friendId: friendId,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        user: _currentUser!,
                        onLogout: _logout,
                        isCurrentUser: true,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(
                          _currentUser!.displayName.isNotEmpty
                              ? _currentUser!.displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Consumer<FriendProvider>(
              builder: (context, friendProvider, child) {
                List<dynamic> displayList = _searchQuery.isEmpty
                    ? friendProvider.friends
                    : friendProvider.friends
                        .where((friend) =>
                            friend.displayName
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            friend.username
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                        .toList();

                return Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search friends...',
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                    // Groups Section
                    Consumer<RoomProvider>(
                      builder: (context, roomProvider, _) {
                        final groups = roomProvider.rooms.where((r) => r.roomType == 'GROUP').toList();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                'Groups',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: groups.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    // New Group Button
                                    return InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Column(
                                          children: [
                                            CircleAvatar(
                                              radius: 28,
                                              backgroundColor: Colors.grey[200],
                                              child: const Icon(Icons.add, color: Colors.black54),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text('New', style: TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final room = groups[index - 1];
                                  
                                  return InkWell(
                                    onTap: () {
                                      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChangeNotifierProvider.value(
                                            value: chatProvider,
                                            child: ChatScreen(
                                              roomId: room.id,
                                              roomName: room.name,
                                              userId: _userId ?? 0,
                                              username: _username,
                                              friendId: 0,
                                              isGroup: true,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: Colors.blue[100],
                                            child: const Icon(Icons.groups, color: Colors.blue),
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            width: 60,
                                            child: Text(
                                              room.name,
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Divider(),
                          ],
                        );
                      },
                    ),
                    // Friends list
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Direct Messages',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    // Direct Messages Section
                    Consumer<RoomProvider>(
                      builder: (context, roomProvider, _) {
                        final dmRooms = roomProvider.rooms
                            .where((r) => r.roomType == 'DM')
                            .toList();

                        if (dmRooms.isEmpty) {
                          return _buildEmptyFriends(friendProvider);
                        }

                        List<ChatRoom> filteredRooms = dmRooms;
                        if (_searchQuery.isNotEmpty) {
                          filteredRooms = dmRooms
                              .where((r) => r.name
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()))
                              .toList();
                        }

                        return Expanded(
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filteredRooms.length,
                            itemBuilder: (context, index) {
                              final room = filteredRooms[index];
                              
                              // Extract friend name from "User1 & User2"
                              final displayName = room.name
                                  .replaceAll(_username, '')
                                  .replaceAll('&', '')
                                  .trim();

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.2),
                                  child: Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                                title: Text(displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  room.lastMessage ?? 'No messages yet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatLastSeen(room.lastMessageTimestamp),
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right,
                                        size: 16, color: Colors.grey),
                                  ],
                                ),
                                onTap: () {
                                  final chatProvider = Provider.of<ChatProvider>(
                                      context,
                                      listen: false);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChangeNotifierProvider.value(
                                        value: chatProvider,
                                        child: ChatScreen(
                                          roomId: room.id,
                                          roomName: displayName,
                                          userId: _userId ?? 0,
                                          username: _username,
                                          friendId: 0,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FriendsListScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyFriends(FriendProvider friendProvider) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text('No conversations yet'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FriendsListScreen()),
              ),
              icon: const Icon(Icons.message),
              label: const Text('Start Chatting'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inDays == 0) {
      if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    }
  }
}
