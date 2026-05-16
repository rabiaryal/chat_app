import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../providers/friend_provider.dart';
import '../../services/realtime/chat_controller.dart';
import 'chat_screen.dart';
import '../../providers/chat_provider.dart';
import '../../utils/snackbar_utils.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    _apiService = context.read<ApiService>();
    _chatController = ChatController(apiService: _apiService);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final userResult = await _apiService.getCurrentUser().run();
    
    userResult.fold(
      (failure) => print('Error loading initial data: ${failure.message}'),
      (user) async {
        if (mounted) {
          setState(() => _currentUserId = user.id);

          // Load all friend data
          final friendProvider =
              Provider.of<FriendProvider>(context, listen: false);
          await friendProvider.loadAllFriendsData();
          await friendProvider.loadSuggestedUsers();
        }
      },
    );
  }

  Future<void> _refreshNewFriends() async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      await friendProvider.loadSuggestedUsers();
    } else {
      await friendProvider.searchUsers(query);
    }
  }

  Future<void> _refreshRequests() async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.loadIncomingRequests();
    await friendProvider.loadOutgoingRequests();
  }

  Future<void> _refreshCurrentTab() async {
    if (_tabController.index == 0) {
      await _refreshNewFriends();
    } else {
      await _refreshRequests();
    }
  }

  void _openSearchInNewFriends() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    friendProvider.searchUsers(_searchController.text.trim());
  }

  Future<void> _startChat(int friendId, String friendUsername) async {
    if (_currentUserId == null) return;

    try {
      final response =
          await _chatController.initializeChat(targetUserId: friendId);

      if (!mounted) return;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      context.push('/chat', extra: {
        'roomId': response.roomId,
        'roomName': response.roomName,
        'userId': _currentUserId!,
        'username': friendUsername,
        'friendId': friendId,
        'isGroup': false,
      });
    } catch (e) {
      SnackbarUtils.showError(context, 'Error starting chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshCurrentTab,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'New Friends'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNewFriendsTab(),
                _buildRequestsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewFriendsTab() {
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, child) {
        if (friendProvider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        final query = _searchController.text.trim();
        final users = query.isEmpty 
            ? friendProvider.suggestedUsers 
            : friendProvider.searchResults.take(5).toList();

        return RefreshIndicator(
          onRefresh: _refreshNewFriends,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search new friends...',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  final provider = Provider.of<FriendProvider>(
                                    context,
                                    listen: false,
                                  );
                                  provider.clearSearch();
                                  provider.searchUsers('');
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        final friendProvider = Provider.of<FriendProvider>(
                          context,
                          listen: false,
                        );
                        friendProvider.searchUsers(value);
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _refreshNewFriends,
                    tooltip: 'Refresh new friends',
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (users.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          query.isEmpty
                              ? 'No users available'
                              : 'No users found',
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...users.map((user) {
                  final isFriend = friendProvider.friends
                      .any((friend) => friend.id == user.id);
                  final hasRequest = friendProvider.outgoingRequests.any(
                    (req) => req.toUserId == user.id,
                  );

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[200],
                        child: Text(user.displayName[0].toUpperCase()),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(user.username),
                      trailing: isFriend
                          ? Text(
                              'Friends',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 12),
                            )
                          : hasRequest
                              ? Text(
                                  'Requested',
                                  style: TextStyle(
                                      color: Colors.orange, fontSize: 12),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    final success = await friendProvider
                                        .sendFriendRequest(user.id);
                                    if (success && mounted) {
                                      SnackbarUtils.showSuccess(context, 'Friend request sent to ${user.displayName}');
                                    }
                                  },
                                  icon: Icon(Icons.person_add, size: 16),
                                  label: Text('Add'),
                                ),
                      onTap: isFriend
                          ? () => _startChat(user.id, user.displayName)
                          : null,
                    ),
                  );
                }).toList(),
            ],
          ),
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

        return RefreshIndicator(
          onRefresh: _refreshRequests,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pending Requests',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search),
                    onPressed: _openSearchInNewFriends,
                    tooltip: 'Search new friends',
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _refreshRequests,
                    tooltip: 'Refresh requests',
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (friendProvider.incomingRequests.isEmpty &&
                  friendProvider.outgoingRequests.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(
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
                  ),
                )
              else ...[
                if (friendProvider.incomingRequests.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Incoming Requests (${friendProvider.incomingRequests.length})',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  ...friendProvider.incomingRequests.map((request) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[200],
                          child: Text(
                              request.requesterDisplayName[0].toUpperCase()),
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
                                  SnackbarUtils.showInfo(context, 'Friend request rejected');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
                if (friendProvider.outgoingRequests.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      'Outgoing Requests (${friendProvider.outgoingRequests.length})',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  ...friendProvider.outgoingRequests.map((request) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: Text(request.toUsername[0].toUpperCase()),
                        ),
                        title: Text(request.toUsername),
                        subtitle: Text('Request pending'),
                        trailing: Icon(Icons.schedule, color: Colors.orange),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
