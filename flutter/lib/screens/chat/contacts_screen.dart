import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/friend.dart';
import '../../providers/friend_provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/api_service.dart';
import 'package:chat_app/utils/error_handler.dart';
import 'package:provider/provider.dart' as pprovider;

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final friendProvider =
        pprovider.Provider.of<FriendProvider>(context, listen: true);
    final presenceSet = ref.watch(presenceProvider);
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    // Filter friends based on search query
    final filteredFriends = _searchQuery.isEmpty
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
        // Search Bar
        Padding(
          padding: EdgeInsets.all(16.w),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        // Friends List
        Expanded(
          child: filteredFriends.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No contacts yet'
                        : 'No results found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredFriends.length,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    final isOnline =
                        presenceSet.contains(friend.id) || friend.isOnline;

                    return GestureDetector(
                      onTap: () => _openDirectMessage(context, friend),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 50.w,
                              height: 50.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(0.1),
                                image: friend.avatar != null
                                    ? DecorationImage(
                                        image: NetworkImage(friend.avatar!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: friend.avatar == null
                                  ? Center(
                                      child: Text(
                                        friend.displayName.isNotEmpty
                                            ? friend.displayName[0]
                                                .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(width: 12.w),
                            // Friend Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          friend.displayName,
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Online Status Dot
                                      Container(
                                        width: 8.w,
                                        height: 8.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isOnline
                                              ? Colors.green
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: isOnline
                                          ? Colors.green
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            // Message Button
                            Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(0.1),
                              ),
                              child: Icon(
                                Icons.message_outlined,
                                color: primaryColor,
                                size: 20.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openDirectMessage(BuildContext context, Friend friend) async {
    final roomProvider =
        pprovider.Provider.of<RoomProvider>(context, listen: false);
    final apiService = context.read<ApiService>();

    // Get current user info
    final currentUserResult = await apiService.getCurrentUser().run();

    currentUserResult.fold(
      (failure) {
        if (mounted) {
          ErrorHandler.handle(context, failure, title: 'User Error');
        }
      },
      (currentUser) async {
        final result = await apiService.getOrCreateDirectRoom(friend.id).run();

        result.fold(
          (failure) {
            if (mounted) {
              ErrorHandler.handle(context, failure, title: 'Chat Error');
            }
          },
          (room) {
            if (!mounted) return;

            if (room.id.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid room ID from server')),
              );
              return;
            }

            context.push('/chat', extra: {
              'roomId': room.id,
              'roomName': friend.displayName,
              'userId': currentUser.id,
              'username': currentUser.username,
              'friendId': friend.id,
              'isGroup': false,
            });
          },
        );
      },
    );
  }
}
