/// Chat List Screen - Friends Centered
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/chat_controller.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../models/user.dart';
import 'chat_screen.dart';
import 'friends_list_screen.dart';
import 'user_profile_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _chatController = ChatController(apiService: _apiService);
    _initializeAndLoad();
  }

  @override
  void dispose() {
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

      // Load friends using FriendProvider
      if (mounted) {
        final friendProvider =
            Provider.of<FriendProvider>(context, listen: false);
        await friendProvider.loadFriends();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading friends: $e')),
        );
      }
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
        title: Text('Messages'),
        elevation: 0,
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: Icon(Icons.person),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    user: _currentUser!,
                    onLogout: _logout,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Consumer<FriendProvider>(
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
                    // Friends list
                    Expanded(
                      child: friendProvider.friends.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text('No friends yet'),
                                  SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => showAddFriendBottomSheet(
                                      context,
                                      onSearchTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                FriendsListScreen()),
                                      ),
                                      onRequestsTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                FriendsListScreen()),
                                      ),
                                    ),
                                    icon: Icon(Icons.add),
                                    label: Text('Find Friends'),
                                  ),
                                ],
                              ),
                            )
                          : displayList.isEmpty
                              ? Center(
                                  child: Text('No friends match your search'),
                                )
                              : ListView.builder(
                                  itemCount: displayList.length,
                                  itemBuilder: (context, index) {
                                    final friend = displayList[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue[200],
                                        child: Text(friend.displayName[0]
                                            .toUpperCase()),
                                      ),
                                      title: Text(friend.displayName),
                                      subtitle: Text(
                                        friend.isOnline ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          color: friend.isOnline
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                      trailing: Icon(Icons.chevron_right),
                                      onTap: () => _startChat(
                                          friend.id, friend.displayName),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddFriendBottomSheet(
          context,
          onSearchTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FriendsListScreen()),
          ),
          onRequestsTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FriendsListScreen()),
          ),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}
