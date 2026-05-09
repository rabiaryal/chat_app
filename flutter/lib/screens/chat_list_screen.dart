import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/chat_controller.dart';
import '../providers/friend_provider.dart';
import '../providers/room_provider.dart';
import '../models/user.dart';
import '../models/chat_room.dart';

// New Modular Widgets
import '../widgets/dashboard/chat_app_bar.dart';
import '../widgets/dashboard/user_status_bar.dart';
import '../widgets/dashboard/chat_tabs.dart';
import '../widgets/dashboard/chat_card.dart';
import '../widgets/dashboard/dashboard_bottom_nav.dart';
import '../utils/snackbar_utils.dart';

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
  int _selectedTabIndex = 0;
  int _selectedBottomIndex = 0;
  final ScrollController _scrollController = ScrollController();

  final List<String> _tabs = ['All', 'Unread', 'Groups', 'Favorites'];

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
      final sessionRestored = await _apiService.restoreSession();

      if (!sessionRestored) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
        return;
      }

      if (mounted) {
        await _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showError(context, 'Session error: $e');
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = await _apiService.getCurrentUser();
      _userId = user.id;
      _username = user.username;
      _currentUser = user;

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
        SnackbarUtils.showError(context, 'Error loading data: $e');
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
      await _apiService.logout();
    } catch (e) {
      print('Logout error: $e');
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6C5CE7);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: ChatAppBar(primaryColor: primaryColor),
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: _selectedBottomIndex,
        primaryColor: primaryColor,
        currentUser: _currentUser,
        onLogout: _logout,
        onItemSelected: (index) => setState(() => _selectedBottomIndex = index),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    UserStatusBar(primaryColor: primaryColor),
                    const SizedBox(height: 16),
                    ChatTabs(
                      tabs: _tabs,
                      selectedTabIndex: _selectedTabIndex,
                      primaryColor: primaryColor,
                      onTabSelected: (index) => setState(() => _selectedTabIndex = index),
                    ),
                    const SizedBox(height: 16),
                    _buildChatList(primaryColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search messages or users',
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
        if (_selectedTabIndex == 1) { // Unread
          rooms = rooms.where((r) => r.lastMessageSenderId != null && r.lastMessageSenderId != _userId).toList();
        } else if (_selectedTabIndex == 2) { // Groups
          rooms = rooms.where((r) => r.roomType == 'GROUP').toList();
        } else if (_selectedTabIndex == 3) { // Favorites
          rooms = []; // Not implemented yet
        }

        if (_searchQuery.isNotEmpty) {
          rooms = rooms.where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
