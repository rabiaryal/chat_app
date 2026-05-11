import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_room.dart';
import '../../providers/chat_provider.dart';
import '../../providers/room_provider.dart';
import '../../screens/chat_screen.dart';

class ChatCard extends StatelessWidget {
  final ChatRoom room;
  final Color primaryColor;
  final int? currentUserId;
  final String currentUsername;

  const ChatCard({
    Key? key,
    required this.room,
    required this.primaryColor,
    required this.currentUserId,
    required this.currentUsername,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isGroup = room.roomType == 'GROUP';
    // Use otherParticipantName if available, otherwise fallback to room.name
    final String displayName = isGroup
        ? room.name
        : (room.otherParticipantName.isNotEmpty
            ? room.otherParticipantName
            : room.name);

    final bool hasNewMessage = room.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          onTap: () {
            final chatProvider =
                Provider.of<ChatProvider>(context, listen: false);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider.value(
                  value: chatProvider,
                  child: ChatScreen(
                    roomId: room.id,
                    roomName: displayName,
                    userId: currentUserId ?? 0,
                    username: currentUsername,
                    friendId: isGroup ? 0 : (room.otherParticipantId ?? 0),
                    isGroup: isGroup,
                  ),
                ),
              ),
            );
          },
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: isGroup ? Colors.blue[50] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: isGroup
                ? const Icon(Icons.groups, color: Colors.blue)
                : Center(
                    child: Text(
                        displayName.trim().isNotEmpty
                            ? displayName.trim()[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isGroup)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.groups,
                            size: 18, color: Color(0xFF6C5CE7)),
                      ),
                  ],
                ),
              ),
              Text(
                _formatLastSeen(room.lastMessageTimestamp),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isGroup && room.lastMessageSenderId != null
                        ? '${room.lastMessageSenderId == currentUserId ? "You" : room.lastMessageSenderId}: ${room.lastMessage}'
                        : (room.lastMessage ?? 'No messages yet'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: hasNewMessage ? Colors.black87 : Colors.grey,
                        fontWeight: hasNewMessage
                            ? FontWeight.bold
                            : FontWeight.normal),
                  ),
                ),
                if (hasNewMessage)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('${room.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (value) async {
              final roomProvider =
                  Provider.of<RoomProvider>(context, listen: false);
              if (value == 'mark_read') {
                await roomProvider.markRoomAsRead(room.id);
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Chat'),
                    content: Text(
                        'Are you sure you want to delete your chat with $displayName? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    await roomProvider.deleteRoom(room.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat deleted')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              if (hasNewMessage)
                const PopupMenuItem(
                  value: 'mark_read',
                  child: Row(
                    children: [
                      Icon(Icons.mark_chat_read_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Mark as read'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Delete Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    if (difference.inDays == 0) {
      return '${lastSeen.hour}:${lastSeen.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeen.day}/${lastSeen.month}';
    }
  }
}
