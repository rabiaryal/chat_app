import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/friend.dart';
import '../../services/api_service.dart';

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
                    builder: (context, friendProvider, _) {
                      final matches = friendProvider.friends
                          .where((f) => f.id == friendId)
                          .toList();
                      final Friend? friend =
                          matches.isNotEmpty ? matches.first : null;

                      final bool isOnline = friend?.isOnline ?? false;
                      final statusText = isOnline ? 'Online' : 'Offline';
                      final statusColor = isOnline ? Colors.green : Colors.grey;

                      return Row(
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
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          onSelected: (value) async {
            final roomProvider =
                Provider.of<RoomProvider>(context, listen: false);

            if (value == 'info') {
              if (!context.mounted) return;

              if (isGroup) {
                final maxHeight = MediaQuery.of(context).size.height * 0.55;
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Group Info'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: $roomName',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Members:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: maxHeight,
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: context
                                  .read<ApiService>()
                                  .getRoomMembers(roomId),
                              builder: (ctx, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }

                                if (!snapshot.hasData) {
                                  return const Text('No members found');
                                }

                                final members =
                                    (snapshot.data!['participants'] as List?)
                                            ?.cast<Map<String, dynamic>>() ??
                                        [];

                                return ListView.builder(
                                  itemCount: members.length,
                                  itemBuilder: (ctx, idx) {
                                    final member = members[idx];
                                    final isCreator =
                                        member['is_creator'] ?? false;

                                    return ListTile(
                                      title: Text(
                                        '${member['first_name']?.isEmpty ?? true ? member['username'] : '${member['first_name']} ${member['last_name']}'}'
                                            .trim(),
                                      ),
                                      subtitle: Text('@${member['username']}'),
                                      trailing: isCreator
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text('Creator',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            )
                                          : null,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              } else {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Chat Info'),
                    content: Text(
                        'Chat with $roomName\nType: Direct message\nRoom ID: $roomId'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            } else if (value == 'mark_read') {
              await roomProvider.markRoomAsRead(roomId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversation marked as read')),
                );
              }
            } else if (value == 'add_member') {
              if (!context.mounted) return;

              try {
                final roomData =
                    await context.read<ApiService>().getRoomMembers(roomId);
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

                final maxHeight = MediaQuery.of(context).size.height * 0.55;

                if (!context.mounted) return;
                final selectedUser = await showDialog<Friend>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Add Member'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: candidates.isEmpty
                          ? const Text('No available friends to add')
                          : SizedBox(
                              height: maxHeight,
                              child: ListView.builder(
                                itemCount: candidates.length,
                                itemBuilder: (ctx, index) {
                                  final friend = candidates[index];
                                  return ListTile(
                                    onTap: () =>
                                        Navigator.pop(dialogContext, friend),
                                    leading: CircleAvatar(
                                      radius: 20,
                                      child: Text(friend.displayName.isNotEmpty
                                          ? friend.displayName[0].toUpperCase()
                                          : '?'),
                                    ),
                                    title: Text(friend.displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text('@${friend.username}'),
                                  );
                                },
                              ),
                            ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );

                if (selectedUser != null && context.mounted) {
                  try {
                    await roomProvider.addMember(roomId, selectedUser.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${selectedUser.displayName} has been added to the group')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add member: $e')),
                      );
                    }
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load friends: $e')),
                  );
                }
              }
            } else if (value == 'remove_member') {
              if (!context.mounted) return;

              try {
                final roomData =
                    await context.read<ApiService>().getRoomMembers(roomId);

                // Check if current user is the creator
                final creatorId = roomData['creator_id'];
                final currentUserId =
                    context.read<AuthProvider>().currentUser?.id;

                if (currentUserId != creatorId) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Only the group creator can remove members'),
                      ),
                    );
                  }
                  return;
                }

                final members = (roomData['participants'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                final maxHeight = MediaQuery.of(context).size.height * 0.55;

                if (!context.mounted) return;

                final selectedUserId = await showDialog<int>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Remove Member'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SizedBox(
                        height: maxHeight,
                        child: ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (ctx, idx) {
                            final member = members[idx];
                            final isCreator = member['is_creator'] ?? false;

                            return ListTile(
                              title: Text(
                                '${member['first_name']?.isEmpty ?? true ? member['username'] : '${member['first_name']} ${member['last_name']}'}'
                                    .trim(),
                              ),
                              subtitle: Text('@${member['username']}'),
                              trailing: isCreator
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: const Text('Creator',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold)))
                                  : null,
                              onTap: isCreator
                                  ? null
                                  : () => Navigator.pop(
                                      dialogContext, member['id'] as int),
                            );
                          },
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'))
                    ],
                  ),
                );

                if (selectedUserId != null && context.mounted) {
                  try {
                    await roomProvider.removeMember(roomId, selectedUserId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Member removed from the group')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to remove member: $e')),
                      );
                    }
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load members: $e')),
                  );
                }
              }
            } else if (value == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(isGroup ? 'Leave group' : 'Delete chat'),
                  content: Text(
                    isGroup
                        ? 'Are you sure you want to leave $roomName? This will remove the group from your chat list.'
                        : 'Are you sure you want to delete your chat with $roomName? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(isGroup ? 'Leave' : 'Delete')),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  await roomProvider.deleteRoom(roomId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(isGroup ? 'Left group' : 'Chat deleted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update chat: $e')),
                    );
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
                    Text('Remove member',
                        style: TextStyle(color: Colors.orange)),
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
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
