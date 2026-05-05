/// Main Chat Screen with smart scrolling and real-time messaging
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final int userId;
  final String username;

  const ChatScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ScrollController _scrollController;
  late TextEditingController _messageController;
  bool _shouldAutoScroll = true;
  double _lastScrollPosition = 0;

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
    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // If scrolling up (lower pixel value), disable auto-scroll
    if (currentPosition < _lastScrollPosition) {
      setState(() {
        _shouldAutoScroll = false;
      });
    }

    // If near the bottom, re-enable auto-scroll
    if (currentPosition >= maxScroll - 100) {
      setState(() {
        _shouldAutoScroll = true;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName),
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                return Text(
                  chatProvider.isConnected ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: chatProvider.isConnected
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                );
              },
            ),
          ],
        ),
        elevation: 0,
      ),
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (chatProvider.messages.isNotEmpty) {
                    _scrollToBottom();
                  }
                });

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
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message... (start with @bot for AI)',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        suffixIcon: _messageController.text.isNotEmpty
                            ? Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _messageController.clear,
                                  child: Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        if (value.length == 1) {
                          context.read<ChatProvider>().onUserTyping();
                        }
                        setState(() {});
                      },
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed:
                        _messageController.text.isEmpty ? null : _sendMessage,
                    elevation: 0,
                    backgroundColor: _messageController.text.isEmpty
                        ? Colors.grey[300]
                        : Theme.of(context).primaryColor,
                    child: Icon(
                      Icons.send,
                      color: _messageController.text.isEmpty
                          ? Colors.grey
                          : Colors.white,
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
