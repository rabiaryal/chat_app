/// Main Chat Screen with smart scrolling and real-time messaging
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../widgets/chat_bubble.dart';

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
  late ScrollController _scrollController;
  late TextEditingController _messageController;
  bool _shouldAutoScroll = true;
  double _lastScrollPosition = 0;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _messageController = TextEditingController();

    // Detect if user is manually scrolling
    _scrollController.addListener(_onScroll);

    // Initialize chat room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initialize(
            roomId: widget.roomId,
            userId: widget.userId,
            username: widget.username,
          );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (currentPosition < _lastScrollPosition && currentPosition < maxScroll - 20) {
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
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<ChatProvider>().sendMessage(content);
    _messageController.clear();

    // Auto-scroll to bottom when sending message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _showActionConfirmation(BuildContext context) {
    final title = widget.isGroup ? 'Leave ${widget.roomName}?' : 'Unfriend ${widget.username}?';
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
                Navigator.pop(dialogContext); // Close dialog
                
                bool success = false;
                if (widget.isGroup) {
                  try {
                    await context.read<ApiService>().leaveRoom(widget.roomId);
                    success = true;
                  } catch (e) {
                    print('Error leaving group: $e');
                  }
                } else {
                  success = await Provider.of<FriendProvider>(context, listen: false)
                      .removeFriend(widget.friendId);
                }
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(widget.isGroup ? 'Left group' : 'Unfriended ${widget.username}')),
                  );
                  Navigator.pop(context); // Exit chat screen
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Action failed. Please try again.')),
                  );
                }
              },
              child: Text(actionText, style: const TextStyle(color: Colors.red)),
            ),
          ],
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
                      widget.roomName.isNotEmpty ? widget.roomName[0].toUpperCase() : 'U',
                      style: TextStyle(color: Colors.blueGrey[800], fontSize: 16),
                    ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.roomName.split('&').last.trim(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            icon: Icon(Icons.videocam),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'unfriend') {
                _showActionConfirmation(context);
              } else if (value == 'media') {
                // Placeholder for media
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Media option coming soon!')),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 'media',
                  child: Row(
                    children: [
                      Icon(Icons.perm_media, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Media'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'unfriend',
                  child: Row(
                    children: [
                      Icon(
                        widget.isGroup ? Icons.exit_to_app : Icons.person_remove,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
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
          ? Color(0xFF1E1E1E) 
          : Color(0xFFE5DDD5), // Standard chat background
      body: Column(
        children: [
          // Connection status bar
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              return ConnectionStatusBar(
                isConnected: chatProvider.isConnected,
                onReconnect: () {
                  chatProvider.reconnect();
                },
              );
            },
          ),
          // Messages list
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

                if (chatProvider.isLoading) {
                  return Center(
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
                    // Show typing indicator at the end
                    if (index == chatProvider.messages.length) {
                      return TypingIndicator(
                        username: 'AI Assistant',
                        isBot: true,
                      );
                    }

                    final message = chatProvider.messages[index];
                    final isCurrentUser = message.userId == widget.userId;

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
          // Message input bar
          Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                            offset: Offset(0, 1),
                          )
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
                              icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                              onPressed: () {},
                            ),
                          if (_messageController.text.isEmpty)
                            IconButton(
                              icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                              onPressed: () {},
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: IconButton(
                        icon: Icon(
                          _messageController.text.isEmpty ? Icons.mic : Icons.send,
                          color: Colors.white,
                        ),
                        onPressed: _messageController.text.isEmpty ? null : _sendMessage,
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

/// Empty Chat State Widget
/// Shows when a room is first created with no messages
class EmptyChat extends StatelessWidget {
  final String roomName;

  const EmptyChat({
    Key? key,
    required this.roomName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 24),
          Text(
            'Start the conversation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8),
          Text(
            'Wave to begin chatting with ${roomName.split('&').last.trim()}',
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

/// Connection Status Bar
/// Shows when connection is lost/reconnecting
class ConnectionStatusBar extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onReconnect;

  const ConnectionStatusBar({
    Key? key,
    required this.isConnected,
    required this.onReconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return SizedBox.shrink();
    }

    return Container(
      color: Colors.red.shade100,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: Colors.red,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline - Attempting to reconnect...',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: onReconnect,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Typing Indicator Widget
/// Shows when another user is typing
class TypingIndicator extends StatefulWidget {
  final String username;
  final bool isBot;

  const TypingIndicator({
    Key? key,
    required this.username,
    this.isBot = false,
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            child: Icon(
              Icons.smart_toy,
              size: 12,
              color: Colors.blue,
            ),
            backgroundColor: Colors.blue.shade100,
          ),
          SizedBox(width: 8),
          Text(
            '${widget.username} is typing',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(
                3,
                (index) => ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.2).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        index * 0.2,
                        0.6 + index * 0.2,
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
