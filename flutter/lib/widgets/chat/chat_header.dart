import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as pprovider;
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/presence_provider.dart';
import 'header/widgets/chat_header_menu.dart';

class ChatHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;
  final int friendId;

  const ChatHeader({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.isGroup,
    required this.friendId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200],
            child: Text(
              roomName.trim().isNotEmpty
                  ? roomName.trim()[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isGroup)
                  Builder(builder: (context) {
                    final presenceSet = ref.watch(presenceProvider);
                    final friendProvider =
                        pprovider.Provider.of<FriendProvider>(context,
                            listen: false);
                    final isOnline = presenceSet.isNotEmpty
                        ? presenceSet.contains(friendId)
                        : friendProvider.isUserOnline(friendId);
                    final statusText = isOnline ? 'Online' : 'Offline';
                    final statusColor = isOnline ? Colors.green : Colors.grey;

                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 12, color: statusColor),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ChatHeaderMenu(
          roomId: roomId,
          roomName: roomName,
          isGroup: isGroup,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// removed stray class
