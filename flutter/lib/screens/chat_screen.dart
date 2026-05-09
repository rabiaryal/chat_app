/// Main Chat Screen with smart scrolling and real-time messaging
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/friend.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../services/api_service.dart';
import '../widgets/chat_bubble.dart';

class GroupMemberEntry {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final bool isOnline;

  GroupMemberEntry({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.isOnline,
  });

  String get displayName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    }
    if (firstName.isNotEmpty) {
      return firstName;
    }
    if (lastName.isNotEmpty) {
      return lastName;
    }
    return username;
  }
}

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final int userId;
  final String username;
  final int friendId;
  final bool isGroup;

  const ChatScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.userId,
    required this.username,
    required this.friendId,
    this.isGroup = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _messageController;
  late ChatProvider _chatProvider;

  bool _shouldAutoScroll = true;
  double _lastScrollPosition = 0;
  int _previousMessageCount = 0;

  int? _creatorId;
  List<GroupMemberEntry> _groupMembers = [];
  bool _loadingGroupMembers = false;

  bool get _isGroupCreator => _creatorId != null && _creatorId == widget.userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider = context.read<ChatProvider>();
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _messageController = TextEditingController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider.initialize(
        roomId: widget.roomId,
        userId: widget.userId,
        username: widget.username,
      );
      if (widget.isGroup) {
        _loadGroupMembers();
      }
    });
  }

  @override
  void dispose() {
    _chatProvider.disconnect();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (currentPosition < _lastScrollPosition &&
        currentPosition < maxScroll - 20) {
      _shouldAutoScroll = false;
    }

    if (currentPosition >= maxScroll - 20) {
      _shouldAutoScroll = true;
    }

    _lastScrollPosition = currentPosition;
  }

  void _scrollToBottom() {
    if (_shouldAutoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<ChatProvider>().sendMessage(content);
    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _showActionConfirmation(BuildContext context) {
    final title = widget.isGroup
        ? 'Leave ${widget.roomName}?'
        : 'Unfriend ${widget.username}?';
    final content = widget.isGroup
        ? 'Are you sure you want to leave this group? You will no longer receive messages from this conversation.'
        : 'Are you sure you want to remove ${widget.username} from your friends? This will also end your ability to chat.';
    final actionText = widget.isGroup ? 'Leave' : 'Unfriend';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final apiService = context.read<ApiService>();
                final friendProvider = context.read<FriendProvider>();
                Navigator.pop(dialogContext);

                bool success = false;
                if (widget.isGroup) {
                  try {
                    await apiService.leaveRoom(widget.roomId);
                    success = true;
                  } catch (e) {
                    debugPrint('Error leaving group: $e');
                  }
                } else {
                  success = await friendProvider.removeFriend(widget.friendId);
                }

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(widget.isGroup
                            ? 'Left group'
                            : 'Unfriended ${widget.username}')),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Action failed. Please try again.')),
                  );
                }
              },
              child:
                  Text(actionText, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddMemberSheet() async {
    if (!_isGroupCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the group creator can add members')),
      );
      return;
    }

    final friendProvider = context.read<FriendProvider>();

    if (friendProvider.friends.isEmpty && !friendProvider.isLoading) {
      await friendProvider.loadFriends(refresh: true);
    }

    if (!mounted) return;

    final friends = friendProvider.friends;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No friends available to add')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Add member',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Choose one of your friends to add to this group.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 420,
                  child: ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final Friend friend = friends[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(friend.username.isNotEmpty
                              ? friend.username[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(friend.displayName),
                        subtitle: Text('@${friend.username}'),
                        trailing: const Icon(Icons.person_add_alt_1),
                        onTap: () async {
                          final apiService = context.read<ApiService>();
                          Navigator.pop(sheetContext);
                          try {
                            await apiService.addRoomMember(
                                  roomId: widget.roomId,
                                  userId: friend.id,
                                );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '${friend.displayName} added to the group')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to add member: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadGroupMembers({bool refresh = false}) async {
    if (_loadingGroupMembers && !refresh) return;
    setState(() => _loadingGroupMembers = true);

    try {
      final payload =
          await context.read<ApiService>().getRoomMembers(widget.roomId);
      final participants = (payload['participants'] as List<dynamic>? ?? [])
          .map(
            (member) => GroupMemberEntry(
              id: member['id'] as int,
              username: member['username'] as String? ?? '',
              firstName: member['first_name'] as String? ?? '',
              lastName: member['last_name'] as String? ?? '',
              isOnline: member['is_online'] as bool? ?? false,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _creatorId = payload['creator_id'] as int?;
        _groupMembers = participants;
        _loadingGroupMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingGroupMembers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load group members: $e')),
      );
    }
  }

  Future<void> _showMembersSheet() async {
    if (widget.isGroup) {
      await _loadGroupMembers(refresh: true);
    }

    if (!mounted) return;

    final members = _groupMembers;
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members found for this group')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Group members',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _isGroupCreator
                      ? 'You can remove members from this group.'
                      : 'View all members in this group.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 420,
                  child: ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isCreatorMember = member.id == _creatorId;
                      final canRemove = _isGroupCreator &&
                          !isCreatorMember &&
                          member.id != widget.userId;
                      final statusText = member.isOnline ? 'Online' : 'Offline';
                      final statusColor =
                          member.isOnline ? Colors.green : Colors.grey;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(member.username.isNotEmpty
                              ? member.username[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(member.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '@${member.username}${isCreatorMember ? ' • Creator' : ''}'),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                      fontSize: 12, color: statusColor),
                                ),
                                if (member.id == widget.userId) ...[
                                  const SizedBox(width: 8),
                                  const Text('You',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueGrey)),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: canRemove
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                                onPressed: () async {
                                  final apiService = context.read<ApiService>();
                                  Navigator.pop(sheetContext);
                                  try {
                                    await apiService.removeRoomMember(
                                      roomId: widget.roomId,
                                      userId: member.id,
                                    );
                                    if (!mounted) return;
                                    await _loadGroupMembers(refresh: true);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              '${member.displayName} removed from the group')),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Failed to remove member: $e')),
                                    );
                                  }
                                },
                              )
                            : (isCreatorMember
                                ? const Padding(
                                    padding: EdgeInsets.only(right: 12.0),
                                    child: Icon(Icons.verified,
                                        color: Colors.blueGrey),
                                  )
                                : null),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueGrey[100],
              child: widget.isGroup
                  ? const Icon(Icons.groups, color: Colors.blueGrey, size: 20)
                  : Text(
                      widget.roomName.isNotEmpty
                          ? widget.roomName[0].toUpperCase()
                          : 'U',
                      style:
                          TextStyle(color: Colors.blueGrey[800], fontSize: 16),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.roomName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      if (widget.isGroup) {
                        return const Text(
                          'Group Chat',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        );
                      }
                      return Text(
                        chatProvider.isConnected ? 'Online' : 'Offline',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: chatProvider.isConnected
                                  ? Colors.white70
                                  : Colors.red[200],
                              fontSize: 12,
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'unfriend') {
                _showActionConfirmation(context);
              } else if (value == 'add_member') {
                _showAddMemberSheet();
              } else if (value == 'members') {
                _showMembersSheet();
              } else if (value == 'media') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Media option coming soon!')),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'media',
                  child: Row(
                    children: [
                      Icon(Icons.perm_media, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Media'),
                    ],
                  ),
                ),
                if (widget.isGroup)
                  const PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(Icons.people, color: Colors.black54),
                        SizedBox(width: 8),
                        Text('Members'),
                      ],
                    ),
                  ),
                if (_isGroupCreator)
                  const PopupMenuItem(
                    value: 'add_member',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.black54),
                        SizedBox(width: 8),
                        Text('Add Member'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'unfriend',
                  child: Row(
                    children: [
                      Icon(
                        widget.isGroup
                            ? Icons.exit_to_app
                            : Icons.person_remove,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isGroup ? 'Leave Group' : 'Unfriend',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFE5DDD5),
      body: Column(
        children: [
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              return ConnectionStatusBar(
                isConnected: chatProvider.isConnected,
                onReconnect: chatProvider.reconnect,
              );
            },
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final currentMessageCount = chatProvider.messages.length;
                if (currentMessageCount > _previousMessageCount) {
                  _previousMessageCount = currentMessageCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_shouldAutoScroll) {
                      _scrollToBottom();
                    }
                  });
                }

                if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading chat...'),
                      ],
                    ),
                  );
                }

                if (chatProvider.messages.isEmpty) {
                  return EmptyChat(roomName: widget.roomName);
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: chatProvider.messages.length +
                      (chatProvider.typingIndicator != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chatProvider.messages.length &&
                        chatProvider.typingIndicator != null) {
                      return TypingIndicator(
                        username: chatProvider.typingIndicator?.username ??
                            'AI Assistant',
                        isBot: true,
                      );
                    }

                    final message = chatProvider.messages[index];
                    final isCurrentUser = message.userId == widget.userId;

                    // Real-time: mark incoming messages as read when they appear
                    if (!isCurrentUser && message.status != MessageStatus.read) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        chatProvider.markAsRead(message.id);
                      });
                    }

                    return ChatBubble(
                      message: message,
                      isCurrentUser: isCurrentUser,
                      showAvatar: !isCurrentUser,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 1,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.emoji_emotions_outlined,
                                color: Colors.grey[600]),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              keyboardType: TextInputType.multiline,
                              maxLines: 5,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 12),
                              ),
                              onChanged: (value) {
                                if (value.length == 1) {
                                  context.read<ChatProvider>().onUserTyping();
                                }
                                setState(() {});
                              },
                            ),
                          ),
                          if (_messageController.text.isEmpty)
                            IconButton(
                              icon: Icon(Icons.attach_file,
                                  color: Colors.grey[600]),
                              onPressed: () {},
                            ),
                          if (_messageController.text.isEmpty)
                            IconButton(
                              icon: Icon(Icons.camera_alt,
                                  color: Colors.grey[600]),
                              onPressed: () {},
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: IconButton(
                        icon: Icon(
                          _messageController.text.isEmpty
                              ? Icons.mic
                              : Icons.send,
                          color: Colors.white,
                        ),
                        onPressed: _messageController.text.isEmpty
                            ? null
                            : _sendMessage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyChat extends StatelessWidget {
  final String? roomName;

  const EmptyChat({
    Key? key,
    this.roomName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            roomName != null
                ? 'Say hello to ${roomName!.split('&').last.trim()}'
                : 'Open the chat to begin',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
