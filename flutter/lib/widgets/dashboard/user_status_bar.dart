import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as pprovider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/friend_provider.dart';
import '../../providers/room_provider.dart';
import '../../screens/chat/create_group_screen.dart';
import '../../providers/presence_provider.dart';

class UserStatusBar extends ConsumerWidget {
  final Color primaryColor;

  const UserStatusBar({Key? key, required this.primaryColor}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceSet = ref.watch(presenceProvider);
    return SizedBox(
      height: 100,
      child: pprovider.Consumer2<RoomProvider, FriendProvider>(
        builder: (context, roomProvider, friendProvider, _) {
          final friends = presenceSet.isNotEmpty
              ? friendProvider.friends
                  .where((friend) => presenceSet.contains(friend.id))
                  .toList()
              : friendProvider.friends
                  .where((friend) => friend.isOnline)
                  .toList();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: friends.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildNewGroupButton(context);
              }
              final friend = friends[index - 1];
              return _buildUserStatusAvatar(friend);
            },
          );
        },
      ),
    );
  }

  Widget _buildNewGroupButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateGroupScreen()),
            ),
            child: Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.groups, color: primaryColor, size: 30),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: primaryColor, shape: BoxShape.circle),
                      child:
                          const Icon(Icons.add, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('New Group',
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildUserStatusAvatar(dynamic friend) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: friend.avatar != null
                      ? DecorationImage(
                          image: NetworkImage(friend.avatar!),
                          fit: BoxFit.cover)
                      : null,
                  color: Colors.grey[200],
                ),
                child: friend.avatar == null
                    ? Center(
                        child: Text(friend.username[0].toUpperCase(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)))
                    : null,
              ),
              if (friend.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.35),
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
          const SizedBox(height: 4),
          Text(friend.username,
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
