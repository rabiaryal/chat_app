/// Chat State Management using Provider
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/chat_message.dart';
import '../models/message_model.dart';
import '../services/chat_persistence_service.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService chatService;
  final ChatPersistenceService _persistenceService;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;
  String? _currentRoomId;
  int? _currentUserId;
  String? _currentUsername;
  ChatMessage? _typingIndicator;

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String? get currentRoomId => _currentRoomId;
  ChatMessage? get typingIndicator => _typingIndicator;

  ChatProvider({required this.chatService})
      : _persistenceService = ChatPersistenceService() {
    // Listen to WebSocket messages
    chatService.messageStream.listen(
      _onMessageReceived,
      onError: _onError,
    );

    // Listen to connection status
    chatService.connectionStream.listen(
      (isConnected) {
        _isConnected = isConnected;
        _notifySafely();
      },
    );
  }

  void _notifySafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Initialize chat provider with room and user info
  Future<void> initialize({
    required String roomId,
    required int userId,
    required String username,
  }) async {
    // Prevent redundant initialization for the same room
    if (_currentRoomId == roomId && _isConnected && _messages.isNotEmpty) {
      print('ℹ ChatProvider already initialized for room: $roomId');
      return;
    }

    _currentRoomId = roomId;
    _currentUserId = userId;
    _currentUsername = username;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      await _persistenceService.initialize();
      final cachedMessages = await _persistenceService.getMessages(
        roomId,
        recoveryCallback: () async {
          final backendMessages = await chatService.apiService.getMessages(
            roomId,
            limit: 20,
          );
          final recoveredModels =
              backendMessages.map(MessageModel.fromChatMessage).toList();
          return recoveredModels;
        },
      );

      _messages =
          cachedMessages.map((message) => message.toChatMessage()).toList();

      await chatService.connectWebSocket(roomId: roomId);
      _isConnected = true;
      _isLoading = false;
      _notifySafely();
    } catch (e) {
      print('✗ Chat initialization connection error: $e');
      _isConnected = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  /// Send a text message
  void sendMessage(String content) {
    if (content.isEmpty || _currentRoomId == null || _currentUserId == null) {
      return;
    }

    // Check if message is for bot
    if (content.startsWith('@bot ')) {
      final botMessage = content.substring(5);
      _requestBotResponse(botMessage);
    } else {
      // Create local message immediately
      final localMessage = ChatMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        userId: _currentUserId!,
        username: _currentUsername ?? 'Unknown',
        roomId: _currentRoomId!,
        type: MessageType.text,
        status: MessageStatus.sending,
        isBot: false,
        timestamp: DateTime.now(),
      );

      // Add to UI immediately
      _messages.add(localMessage);
      _notifySafely();

      // Save to Hive immediately (with status: sending)
      unawaited(
        _persistenceService.addMessage(
          _currentRoomId!,
          MessageModel.fromChatMessage(localMessage),
        ),
      );

      // Send via WebSocket
      chatService.sendTextMessage(
        content: content,
        roomId: _currentRoomId!,
        userId: _currentUserId!,
        username: _currentUsername ?? 'Unknown',
      );
    }
  }

  /// Request bot response
  void _requestBotResponse(String content) {
    if (_currentRoomId == null || _currentUserId == null) {
      return;
    }

    // Add user message immediately
    final userMessage = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      userId: _currentUserId!,
      username: _currentUsername ?? 'Unknown',
      roomId: _currentRoomId!,
      type: MessageType.text,
      status: MessageStatus.sending,
      isBot: false,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);

    // Save to Hive immediately
    unawaited(
      _persistenceService.addMessage(
        _currentRoomId!,
        MessageModel.fromChatMessage(userMessage),
      ),
    );

    // Show "Bot is thinking..." indicator
    _typingIndicator = ChatMessage(
      id: 'typing_indicator',
      content: '',
      userId: 0,
      username: 'AI Assistant',
      roomId: _currentRoomId!,
      status: MessageStatus.streaming,
      isBot: true,
      timestamp: DateTime.now(),
    );
    _notifySafely();

    chatService.requestAIResponse(
      content: content,
      roomId: _currentRoomId!,
      userId: _currentUserId!,
      username: _currentUsername ?? 'Unknown',
    );
  }

  /// Send typing indicator
  void onUserTyping() {
    if (_currentRoomId != null) {
      chatService.sendTypingIndicator(_currentRoomId!);
    }
  }

  /// Handle incoming message
  void _onMessageReceived(ChatMessage message) {
    // Clear typing indicator if receiving a message
    if (message.isBot && message.status == MessageStatus.streaming) {
      _typingIndicator = null;
    }

    // Check if this is a "read receipt" event for an existing message
    if (message.status == MessageStatus.read) {
      print('📖 Received read receipt for message: ${message.id}');
      final existingIndex = _messages.indexWhere((m) => m.id == message.id);
      if (existingIndex != -1) {
        if (_messages[existingIndex].status != MessageStatus.read) {
          _messages[existingIndex] = _messages[existingIndex].copyWith(
            status: MessageStatus.read,
          );
          
          // Update Hive cache
          if (_currentRoomId != null) {
            unawaited(
              _persistenceService.updateMessageId(
                _currentRoomId!,
                message.id,
                MessageModel.fromChatMessage(_messages[existingIndex]),
              ),
            );
          }
          _notifySafely();
          print('✓ Updated message ${message.id} status to READ');
        }
      } else {
        print('⚠ Message ${message.id} not found in local list for read receipt');
      }
      return;
    }

    // Check if this is a delivery confirmation for a message we sent locally
    if (message.id.startsWith('local_')) {
      // This is a local message from sendTextMessage, add it
      _messages.add(message);
    } else {
      // Check if this is a server confirmation of a local message
      final localMessageIndex = _messages.indexWhere(
        (m) =>
            m.id.startsWith('local_') &&
            m.content == message.content &&
            m.userId == message.userId &&
            m.roomId == message.roomId,
      );

      if (localMessageIndex != -1) {
        final oldLocalId = _messages[localMessageIndex].id;
        // Update the local message with server ID and mark as delivered
        _messages[localMessageIndex] = _messages[localMessageIndex].copyWith(
          id: message.id,
          status: MessageStatus.delivered,
        );

        // Update Hive cache: delete old local message, save with new server ID
        if (_currentRoomId != null) {
          unawaited(
            _persistenceService.updateMessageId(
              _currentRoomId!,
              oldLocalId,
              MessageModel.fromChatMessage(_messages[localMessageIndex]),
            ),
          );
        }
      } else {
        // This is a message from someone else or a new message
        _messages.add(message);

        // Save new messages to Hive cache
        if (_currentRoomId != null) {
          unawaited(
            _persistenceService.addMessage(
              _currentRoomId!,
              MessageModel.fromChatMessage(message),
            ),
          );
        }
      }
    }

    _error = null;
    _notifySafely();
  }

  /// Handle errors
  void _onError(dynamic error) {
    _error = error.toString();
    _notifySafely();
  }

  /// Mark message as read
  void markAsRead(String messageId) {
    if (_currentRoomId == null) return;

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      // Only send if it's not already read and it's NOT our own message
      if (_messages[index].status != MessageStatus.read && 
          _messages[index].userId != _currentUserId) {
        
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.read,
        );
        
        // Notify server
        chatService.sendMarkRead(_currentRoomId!, messageId);
        
        // Update Hive
        unawaited(
          _persistenceService.updateMessageId(
            _currentRoomId!,
            messageId,
            MessageModel.fromChatMessage(_messages[index]),
          ),
        );
        
        _notifySafely();
      }
    }
  }

  /// Clear messages
  void clearMessages() {
    _messages.clear();
    _error = null;
    _notifySafely();
  }

  /// Reconnect WebSocket
  Future<void> reconnect() async {
    if (_currentRoomId != null) {
      try {
        _isLoading = true;
        _error = null;
        _notifySafely();

        await chatService.connectWebSocket(roomId: _currentRoomId!);
        _isConnected = true;
        _isLoading = false;
        _notifySafely();
      } catch (e) {
        _error = 'Reconnection failed: $e';
        _isLoading = false;
        _notifySafely();
      }
    }
  }

  /// Disconnect from current room
  Future<void> disconnect() async {
    _currentRoomId = null;
    _isConnected = false;
    _messages = [];
    _notifySafely();
    await chatService.disconnectWebSocket();
  }

  @override
  void dispose() {
    chatService.dispose();
    super.dispose();
  }
}
