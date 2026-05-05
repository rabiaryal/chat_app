/// Custom chat bubble widgets
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final bool showAvatar;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    this.showAvatar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser && showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.avatarUrl != null
                  ? NetworkImage(message.avatarUrl!)
                  : null,
              child: message.avatarUrl == null
                  ? Text(message.username[0].toUpperCase())
                  : null,
            ),
            SizedBox(width: 8),
          ] else if (!isCurrentUser)
            SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Username (for group chats)
                Padding(
                  padding: EdgeInsets.only(
                    left: isCurrentUser ? 0 : 12,
                    right: isCurrentUser ? 12 : 0,
                    bottom: 2,
                  ),
                  child: Text(
                    message.username,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: message.isBot ? Colors.blue : Colors.grey,
                        ),
                  ),
                ),
                // Message bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: _getBubbleColor(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message content
                      if (message.type == MessageType.image &&
                          message.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Text('Failed to load image');
                            },
                          ),
                        )
                      else
                        Text(
                          message.content,
                          style: TextStyle(
                            color: _getTextColor(context),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      SizedBox(height: 4),
                      // Timestamp and status
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.timestamp),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _getTimestampColor(
                                          context, isCurrentUser),
                                      fontSize: 11,
                                    ),
                          ),
                          SizedBox(width: 4),
                          if (isCurrentUser) _buildStatusIcon(context),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBubbleColor(BuildContext context) {
    if (message.isBot) {
      return Colors.grey[200]!;
    }
    return isCurrentUser ? Theme.of(context).primaryColor : Colors.grey[300]!;
  }

  Color _getTextColor(BuildContext context) {
    if (message.isBot) {
      return Colors.black87;
    }
    return isCurrentUser ? Colors.white : Colors.black87;
  }

  Color _getTimestampColor(BuildContext context, bool isCurrentUser) {
    if (message.isBot) {
      return Colors.grey[600]!;
    }
    return isCurrentUser ? Colors.white70 : Colors.grey[600]!;
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white70,
            ),
          ),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.streaming:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white70,
            ),
          ),
        );
      case MessageStatus.error:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red[300],
        );
    }
  }
}

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
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: Duration(milliseconds: 600),
        vsync: this,
      )..repeat(reverse: true),
    );

    // Stagger the animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue,
            child: Text(
              widget.username[0].toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _controllers[index],
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isBot ? Colors.blue : Colors.black54,
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

class ConnectionStatusBar extends StatelessWidget {
  final bool isConnected;
  final VoidCallback? onReconnect;

  const ConnectionStatusBar({
    Key? key,
    required this.isConnected,
    this.onReconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return SizedBox.shrink();
    }

    return Container(
      color: Colors.orange[700],
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Reconnecting...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (onReconnect != null)
            TextButton(
              onPressed: onReconnect,
              child: Text(
                'Retry',
                style: TextStyle(color: Colors.white),
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
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          if (roomName != null) ...[
            SizedBox(height: 8),
            Text(
              'Start a conversation in $roomName',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
