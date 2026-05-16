import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/room_provider.dart';
import '../../../../providers/friend_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/error_handler.dart';
import '../../../../models/friend.dart';
import '../dialogs/group_info_dialog.dart';
import '../dialogs/member_management_dialogs.dart';

class ChatHeaderMenu extends StatelessWidget {
  final String roomId;
  final String roomName;
  final bool isGroup;

  const ChatHeaderMenu({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.isGroup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (value) async {
        if (value == 'info') {
          if (!context.mounted) return;
          if (isGroup) {
            showDialog<void>(
              context: context,
              builder: (ctx) =>
                  GroupInfoDialog(roomId: roomId, roomName: roomName),
            );
          } else {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Chat Info'),
                content: Text(
                    'Chat with $roomName\nType: Direct message\nRoom ID: $roomId'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close')),
                ],
              ),
            );
          }
        } else if (value == 'mark_read') {
          await roomProvider.markRoomAsRead(roomId);
          if (context.mounted) {
            ErrorHandler.showSuccess(context, 'Conversation marked as read');
          }
        } else if (value == 'add_member') {
          if (!context.mounted) return;
          try {
            final result =
                await context.read<ApiService>().getRoomMembers(roomId).run();
            final roomData =
                result.fold((l) => throw Exception(l.message), (r) => r);
            final existing = (roomData['participants'] as List?)
                    ?.map((m) => m['id'] as int)
                    .toSet() ??
                <int>{};
            final creatorId = roomData['creator_id'] as int?;

            final friendProvider =
                Provider.of<FriendProvider>(context, listen: false);
            final candidates = friendProvider.friends
                .where((f) => !existing.contains(f.id) && f.id != creatorId)
                .toList();

            if (!context.mounted) return;
            final selectedUser = await showDialog<Friend>(
              context: context,
              builder: (ctx) => AddMemberDialog(candidates: candidates),
            );

            if (selectedUser != null && context.mounted) {
              try {
                await roomProvider.addMember(roomId, selectedUser.id);
                await context.read<ChatProvider>().refreshMessages();
                if (context.mounted) {
                  ErrorHandler.showSuccess(
                    context,
                    'Added ${selectedUser.displayName} to the group',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.handle(context, e, title: 'Add Member Error');
                }
              }
            }
          } catch (e) {
            if (context.mounted) {
              ErrorHandler.handle(context, e, title: 'Load Friends Error');
            }
          }
        } else if (value == 'remove_member') {
          if (!context.mounted) return;
          try {
            final result =
                await context.read<ApiService>().getRoomMembers(roomId).run();
            final roomData =
                result.fold((l) => throw Exception(l.message), (r) => r);

            final creatorId = roomData['creator_id'];
            final currentUserId = context.read<AuthProvider>().currentUser?.id;

            if (currentUserId != creatorId) {
              if (context.mounted) {
                ErrorHandler.handle(
                    context, 'Only the group creator can remove members');
              }
              return;
            }

            final members = (roomData['participants'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [];

            if (!context.mounted) return;
            final selectedUserId = await showDialog<int>(
              context: context,
              builder: (ctx) => RemoveMemberDialog(members: members),
            );

            if (selectedUserId != null && context.mounted) {
              try {
                await roomProvider.removeMember(roomId, selectedUserId);
                await context.read<ChatProvider>().refreshMessages();
                if (context.mounted) {
                  ErrorHandler.showSuccess(
                      context, 'Removed member from the group');
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.handle(context, e, title: 'Remove Member Error');
                }
              }
            }
          } catch (e) {
            if (context.mounted) {
              ErrorHandler.handle(context, e, title: 'Load Members Error');
            }
          }
        } else if (value == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(isGroup ? 'Leave group' : 'Delete chat'),
              content: Text(
                isGroup
                    ? 'Are you sure you want to leave $roomName? This will remove the group from your chat list.'
                    : 'Are you sure you want to delete your chat with $roomName? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(isGroup ? 'Leave' : 'Delete'),
                ),
              ],
            ),
          );

          if (confirm == true && context.mounted) {
            try {
              await roomProvider.deleteRoom(roomId);
              if (context.mounted) {
                Navigator.of(context).pop();
                ErrorHandler.showSuccess(
                    context, isGroup ? 'Left group' : 'Chat deleted');
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.handle(context, e, title: 'Update Error');
              }
            }
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'info',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 10),
              Text('Chat info'),
            ],
          ),
        ),
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
        if (isGroup) ...[
          const PopupMenuItem(
            value: 'add_member',
            child: Row(
              children: [
                Icon(Icons.person_add, size: 20),
                SizedBox(width: 10),
                Text('Add member'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove_member',
            child: Row(
              children: [
                Icon(Icons.person_remove, size: 20, color: Colors.orange),
                SizedBox(width: 10),
                Text('Remove member', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
        ],
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Text(
                isGroup ? 'Leave group' : 'Delete chat',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
