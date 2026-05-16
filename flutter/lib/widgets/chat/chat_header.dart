import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
import 'header/widgets/chat_header_menu.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
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
                  Consumer<FriendProvider>(
                    builder: (context, friendProvider, child) {
                      final isOnline = friendProvider.isUserOnline(friendId);
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
                    },
                  ),
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    final isConnected = chatProvider.isConnected;
                    final statusText =
                        isConnected ? 'Live' : 'Offline (Reading Cache)';
                    final statusColor = isConnected ? Colors.green : Colors.red;

                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(fontSize: 12, color: statusColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
