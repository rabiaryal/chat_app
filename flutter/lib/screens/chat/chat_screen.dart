import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/room_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/chat/chat_header.dart';
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat_bubble.dart';

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
  late ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _chatProvider.addListener(_onChatError);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomProvider = context.read<RoomProvider>();

      _chatProvider.initialize(
        roomId: widget.roomId,
        userId: widget.userId,
        username: widget.username,
      );

      Future.delayed(Duration.zero, () {
        if (mounted) {
          roomProvider.markRoomAsRead(widget.roomId);
        }
      });
    });
  }

  void _onChatError() {
    if (!mounted) return;
    final error = _chatProvider.error;
    if (error != null) {
      ErrorHandler.handle(context, error);
    }
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onChatError);
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

  Future<void> _refreshMessages() async {
    await context.read<ChatProvider>().refreshMessages();
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
            child: RefreshIndicator(
              onRefresh: _refreshMessages,
              child: Consumer<ChatProvider>(
                //this conusmer is used to provide the error , loading state , etc , 
                builder: (context, chatProvider, _) {
                  return ValueListenableBuilder<Box<Map>>(
                    valueListenable: Hive.box<Map>('chat_box').listenable(),// this is hardcoded has to be user specific
                    builder: (context, box, _) {
                      final messages = box.values
                          .map(
                            (value) => MessageModel.fromJson(
                              Map<String, dynamic>.from(value),
                            ),
                          )
                          .where((message) => message.roomId == widget.roomId)
                          .map((message) => message.toChatMessage())
                          .toList()
                        ..sort(
                          (left, right) =>
                              left.timestamp.compareTo(right.timestamp),
                        );

                      final isInitialLoading =
                          chatProvider.isLoading && messages.isEmpty;
                      final showTypingIndicator =
                          chatProvider.typingIndicator != null &&
                              messages.isNotEmpty;

                      if (messages.isNotEmpty) {
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _scrollToBottom());
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: isInitialLoading
                            ? 1
                            : messages.isEmpty
                                ? 1
                                : messages.length +
                                    (showTypingIndicator ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (isInitialLoading) {
                            return SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (chatProvider.error != null && messages.isEmpty) {
                            return SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48.sp,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 16.h),
                                    Text('Error: ${chatProvider.error}'),
                                    SizedBox(height: 16.h),
                                    ElevatedButton(
                                      onPressed: () => chatProvider.reconnect(),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (messages.isEmpty) {
                            return SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: Center(
                                child: EmptyChat(roomName: widget.roomName),
                              ),
                            );
                          }

                          if (showTypingIndicator && index == messages.length) {
                            return TypingIndicator(
                              username:
                                  chatProvider.typingIndicator?.username ??
                                      'AI Assistant',
                              isBot: true,
                            );
                          }

                          final message = messages[index];
                          final isCurrentUser = message.userId == widget.userId;

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
                  );
                },
              ),
            ),
          ),
          ChatInput(onSendMessage: _sendMessage),
        ],
      ),
    );
  }
}
