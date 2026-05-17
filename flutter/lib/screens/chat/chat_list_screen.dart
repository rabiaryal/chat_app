import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart' as pprovider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/room_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/presence_provider.dart';
import '../../models/chat_room.dart';
import '../../features/auth/models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/dashboard/chat_card.dart';
import '../../widgets/dashboard/chat_app_bar.dart';
import '../../widgets/dashboard/dashboard_bottom_nav.dart';
import '../../widgets/chat_bubble.dart';
import '../../features/auth/provider/auth_provider.dart';
import 'package:chat_app/utils/error_handler.dart';
import 'contacts_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
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
    final roomProvider =
        pprovider.Provider.of<RoomProvider>(context, listen: false);
    final friendProvider =
        pprovider.Provider.of<FriendProvider>(context, listen: false);
    final apiService = context.read<ApiService>();

    await roomProvider.loadRooms();
    // Ensure friends are loaded so the horizontal list shows immediately
    friendProvider.loadAllFriendsData();

    final userResult = await apiService.getCurrentUser().run();

    if (!mounted) return;

    userResult.fold(
      (failure) {
        setState(() => _isLoading = false);
        ErrorHandler.handle(context, failure, title: 'Profile Error');
      },
      (user) {
        roomProvider.setCurrentUserId(user.id);
        setState(() {
          _currentUser = user;
          _userId = user.id;
          _username = user.username;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _logout() async {
    // Prevent double-tap logout
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return pprovider.Consumer2<RoomProvider, FriendProvider>(
      builder: (context, roomProvider, friendProvider, _) {
        final hasCachedData = roomProvider.rooms.isNotEmpty ||
            friendProvider.friends.isNotEmpty ||
            friendProvider.incomingRequests.isNotEmpty ||
            friendProvider.outgoingRequests.isNotEmpty;

        final dashboardBody = RefreshIndicator(
          onRefresh: () =>
              pprovider.Provider.of<RoomProvider>(context, listen: false)
                  .loadRooms(),
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
        );

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
            onItemSelected: (index) =>
                setState(() => _selectedBottomIndex = index),
          ),
          body: Stack(
            children: [
              _selectedBottomIndex == 2
                  ? const ContactsScreen()
                  : dashboardBody,
              if (_isLoading && !hasCachedData)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (_isLoading && hasCachedData)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalList(Color primaryColor) {
    return pprovider.Consumer<FriendProvider>(
      builder: (context, friendProvider, _) {
        final presenceSet = ref.watch(presenceProvider);
        final onlineFriends = presenceSet.isNotEmpty
            ? friendProvider.friends
                .where((friend) => presenceSet.contains(friend.id))
                .toList()
            : friendProvider.friends
                .where((friend) => friend.isOnline)
                .toList();
        return Container(
          height: 110.h,
          margin: EdgeInsets.symmetric(vertical: 10.h),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: onlineFriends.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // New Group Button
                return Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/create-group'),
                        child: Container(
                          width: 65.w,
                          height: 65.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10.r,
                                offset: Offset(0, 4.h),
                              ),
                            ],
                          ),
                          child:
                              Icon(Icons.add, color: primaryColor, size: 30.sp),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text('New',
                          style:
                              TextStyle(fontSize: 12.sp, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final friend = onlineFriends[index - 1];

              return Padding(
                padding: EdgeInsets.only(right: 15.w),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final roomProvider =
                            pprovider.Provider.of<RoomProvider>(context,
                                listen: false);
                        final apiService = context.read<ApiService>();

                        final result = await apiService
                            .getOrCreateDirectRoom(friend.id)
                            .run();

                        result.fold(
                          (failure) {
                            if (mounted) {
                              ErrorHandler.handle(context, failure,
                                  title: 'Chat Error');
                            }
                          },
                          (room) {
                            if (!mounted) return;

                            // Validate room data
                            if (room.id.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Invalid room ID from server')),
                              );
                              return;
                            }

                            // Navigate to chat
                            context.push('/chat', extra: {
                              'roomId': room.id,
                              'roomName': friend.displayName,
                              'userId': _userId ?? 0,
                              'username':
                                  _username.isNotEmpty ? _username : 'User',
                              'friendId': friend.id,
                              'isGroup': false,
                            });

                            // Add room to provider if it's new
                            if (!roomProvider.rooms
                                .any((r) => r.id == room.id)) {
                              roomProvider.addRoom(room);
                            }
                          },
                        );
                      },
                      child: Container(
                        width: 65.w,
                        height: 65.w,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.w),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10.r,
                              offset: Offset(0, 4.h),
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
                                          fontSize: 20.sp,
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                width: 16.w,
                                height: 16.w,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 10.w,
                                    height: 10.w,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.35),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: 65.w,
                      child: Text(
                        friend.displayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.sp, fontWeight: FontWeight.w500),
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
    return pprovider.Consumer<RoomProvider>(
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
                      context.push('/suggested-friends');
                    }
                  : null,
            ),
          );
        }

        return ListView.builder(
          shrinkWrap:
              true, //means i will take the item only neccessary for my information
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
