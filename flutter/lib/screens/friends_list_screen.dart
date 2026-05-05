/// Friends List Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/friend_provider.dart';
import '../services/chat_controller.dart';
import 'chat_screen.dart';
import '../providers/chat_provider.dart';

class FriendsListScreen extends StatefulWidget {
  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late ApiService _apiService;
  late ChatController _chatController;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _apiService = ApiService();
    _chatController = ChatController(apiService: _apiService);
    _loadInitialData();

    // Load search results when Search tab is opened
    _tabController.addListener(() {
      if (_tabController.index == 2 && mounted) {
        final friendProvider =
            Provider.of<FriendProvider>(context, listen: false);
        // Trigger search with empty query to load all users
        friendProvider.searchUsers('');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = await _apiService.getCurrentUser();
      setState(() => _currentUserId = user.id);

      // Load all friend data
      if (mounted) {
        final friendProvider =
            Provider.of<FriendProvider>(context, listen: false);
        await friendProvider.loadAllFriendsData();
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> _startChat(int friendId, String friendUsername) async {
    if (_currentUserId == null) return;

    try {
      final response =
          await _chatController.initializeChat(targetUserId: friendId);

      if (!mounted) return;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: chatProvider,
            child: ChatScreen(
              roomId: response.roomId,
              roomName: response.roomName,
              userId: _currentUserId!,
              username: friendUsername,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
            Tab(text: 'Search'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar visible in all tabs
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          final friendProvider = Provider.of<FriendProvider>(
                              context,
                              listen: false);
                          friendProvider.clearSearch();
                          // Reload all users when search is cleared
                          friendProvider.searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (query) {
                final friendProvider =
                    Provider.of<FriendProvider>(context, listen: false);
                friendProvider.searchUsers(query);
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(),
                _buildRequestsList(),
                _buildSearchResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, child) {
        if (friendProvider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (friendProvider.friends.isEmpty) {
          return Center(
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
                  onPressed: () => _tabController.animateTo(2),
                  icon: Icon(Icons.add),
                  label: Text('Find Friends'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: friendProvider.friends.length,
          itemBuilder: (context, index) {
            final friend = friendProvider.friends[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[200],
                child: Text(friend.displayName[0].toUpperCase()),
              ),
              title: Text(friend.displayName),
              subtitle: Text(
                friend.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: friend.isOnline ? Colors.green : Colors.grey,
                ),
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: () => _startChat(friend.id, friend.displayName),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList() {
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, child) {
        if (friendProvider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        final incomingCount = friendProvider.incomingRequests.length;
        final outgoingCount = friendProvider.outgoingRequests.length;

        if (incomingCount == 0 && outgoingCount == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text('No pending requests'),
              ],
            ),
          );
        }

        return ListView(
          children: [
            if (incomingCount > 0) ...[
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Incoming Requests ($incomingCount)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...friendProvider.incomingRequests.map((request) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[200],
                    child: Text(request.requesterDisplayName[0].toUpperCase()),
                  ),
                  title: Text(request.requesterDisplayName),
                  subtitle: Text(request.fromUsername),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          final success = await friendProvider
                              .acceptFriendRequest(request.id);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Friend request accepted from ${request.requesterDisplayName}'),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          final success = await friendProvider
                              .rejectFriendRequest(request.id);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Friend request rejected'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            if (outgoingCount > 0) ...[
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Outgoing Requests ($outgoingCount)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...friendProvider.outgoingRequests.map((request) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    child: Text(request.toUsername[0].toUpperCase()),
                  ),
                  title: Text(request.toUsername),
                  subtitle: Text('Request pending'),
                  trailing: Icon(Icons.schedule, color: Colors.orange),
                );
              }).toList(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, child) {
        // Show loading indicator
        if (friendProvider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading users...'),
              ],
            ),
          );
        }

        // Show empty state if no results
        if (friendProvider.searchResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(friendProvider.searchQuery.isEmpty
                    ? 'No users available'
                    : 'No users found'),
              ],
            ),
          );
        }

        // Show users list
        return _buildUsersList(friendProvider);
      },
    );
  }

  Widget _buildUsersList(FriendProvider friendProvider) {
    return ListView.builder(
      itemCount: friendProvider.searchResults.length,
      itemBuilder: (context, index) {
        final user = friendProvider.searchResults[index];
        // Check if already a friend
        final isFriend =
            friendProvider.friends.any((friend) => friend.id == user.id);
        // Check if request already sent
        final hasRequest = friendProvider.outgoingRequests
            .any((req) => req.toUserId == user.id);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue[200],
            child: Text(user.displayName[0].toUpperCase()),
          ),
          title: Text(user.displayName),
          subtitle: Text(user.username),
          trailing: isFriend
              ? Text('Friends',
                  style: TextStyle(color: Colors.green, fontSize: 12))
              : hasRequest
                  ? Text('Requested',
                      style: TextStyle(color: Colors.orange, fontSize: 12))
                  : ElevatedButton.icon(
                      onPressed: () async {
                        final success =
                            await friendProvider.sendFriendRequest(user.id);
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Friend request sent to ${user.displayName}'),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.person_add, size: 16),
                      label: Text('Add'),
                    ),
        );
      },
    );
  }
}
