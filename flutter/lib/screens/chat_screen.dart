import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat/chat_header.dart';
import '../widgets/chat/chat_input.dart';
import '../models/chat_message.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      final roomProvider = context.read<RoomProvider>();

      // Initialize chat provider (loads messages, setup UI)
      chatProvider.initialize(
        roomId: widget.roomId,
        userId: widget.userId,
        username: widget.username,
      );

      // Mark room as read (fire and forget, non-blocking)
      Future.delayed(Duration.zero, () {
        if (mounted) {
          roomProvider.markRoomAsRead(widget.roomId);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(String content) {
    context.read<ChatProvider>().sendMessage(content);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatHeader(
        roomId: widget.roomId,
        roomName: widget.roomName,
        isGroup: widget.isGroup,
        friendId: widget.friendId,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatProvider.error != null &&
                    chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${chatProvider.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => chatProvider.reconnect(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (chatProvider.messages.isEmpty) {
                  return EmptyChat(roomName: widget.roomName);
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

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

                    // Mark incoming messages as read ONLY if they are not already seen
                    if (!isCurrentUser &&
                        !message.isBot &&
                        message.status != MessageStatus.read) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        chatProvider.markAsRead(message.id);
                      });
                    }

                    return ChatBubble(
                      key: ValueKey(message.id),
                      message: message,
                      isCurrentUser: isCurrentUser,
                      showAvatar: !isCurrentUser,
                    );
                  },
                );
              },
            ),
          ),
          ChatInput(onSendMessage: _sendMessage),
        ],
      ),
    );
  }
}
