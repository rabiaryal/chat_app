/// Chat State Management using Provider
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/chat_message.dart';
import '../models/message_model.dart';
import '../services/realtime/chat_service.dart';
import '../services/storage/chat_persistence_service.dart';

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

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String? get currentRoomId => _currentRoomId;
  ChatMessage? get typingIndicator => _typingIndicator;

  ChatProvider({required this.chatService})
      : _persistenceService = ChatPersistenceService() {
    chatService.messageStream.listen(
      _onMessageReceived,
      onError: _onError,
    );

    chatService.connectionStream.listen((isConnected) {
      _isConnected = isConnected;
      _notifySafely();
    });
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

  Future<void> initialize({
    required String roomId,
    required int userId,
    required String username,
  }) async {
    if (_currentRoomId == roomId &&
        _currentUserId == userId &&
        _currentUsername == username &&
        _isConnected &&
        _messages.isNotEmpty) {
      print('ℹ ChatProvider already initialized for room: $roomId');
      return;
    }

    if (_currentRoomId != null &&
        (_currentRoomId != roomId ||
            _currentUserId != userId ||
            _currentUsername != username)) {
      print('🔄 Reinitializing chat session for room: $roomId');
      await chatService.disconnectWebSocket();
    }

    _currentRoomId = roomId;
    _currentUserId = userId;
    _currentUsername = username;
    _messages = [];
    _isLoading = true;
    _error = null;
    _typingIndicator = null;
    _notifySafely();

    try {
      await _persistenceService.initialize();
      final cachedMessages = await _persistenceService.getMessages(roomId);
      _messages =
          cachedMessages.map((message) => message.toChatMessage()).toList();
      _isConnected = chatService.isConnected;
      _isLoading = false;
      _notifySafely();

      if (_messages.isEmpty) {
        unawaited(_refreshMessagesFromApi(roomId));
      }

      unawaited(_connectInBackground(roomId));
    } catch (error) {
      print('✗ Chat initialization connection error: $error');
      _isConnected = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshMessagesFromApi(String roomId) async {
    if (_isLoading) {
      return;
    }

    final result = await chatService.apiService
        .getMessages(
          roomId,
          limit: 20,
        )
        .run();

    result.fold(
      (failure) {
        print('✗ Message recovery failed: ${failure.message}');
      },
      (backendMessages) {
        final models =
            backendMessages.map(MessageModel.fromChatMessage).toList();
        unawaited(_persistenceService.replaceMessages(roomId, models));
      },
    );
  }

  Future<void> refreshMessages() async {
    final roomId = _currentRoomId;
    if (roomId == null) {
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      final result = await chatService.apiService
          .getMessages(
            roomId,
            limit: 20,
          )
          .run();

      result.fold(
        (failure) {
          _error = failure.message;
        },
        (backendMessages) {
          final models =
              backendMessages.map(MessageModel.fromChatMessage).toList();
          _messages = models.map((message) => message.toChatMessage()).toList();
          unawaited(_persistenceService.replaceMessages(roomId, models));
          _error = null;
        },
      );
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _connectInBackground(String roomId) async {
    try {
      await chatService.connectWebSocket(roomId: roomId);
    } catch (error) {
      print('⚠ Background socket connect failed: $error');
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty ||
        _currentRoomId == null ||
        _currentUserId == null) {
      return;
    }

    if (content.startsWith('@bot ')) {
      _requestBotResponse(content.substring(5));
      return;
    }

    final localMessage = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      userId: _currentUserId!,//reciver userid 
      username: _currentUsername ?? 'Unknown',
      roomId: _currentRoomId!,
      type: MessageType.text,
      status: MessageStatus.sending,
      isBot: false,
      timestamp: DateTime.now(),
    );

    _messages.add(localMessage);
    _notifySafely();

    chatService.sendTextMessage(
      content: content,
      roomId: _currentRoomId!,
      userId: _currentUserId!,
      username: _currentUsername ?? 'Unknown',
    );
  }

  void _requestBotResponse(String content) {
    if (_currentRoomId == null || _currentUserId == null) {
      return;
    }

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

  void onUserTyping() {
    if (_currentRoomId != null) {
      chatService.sendTypingIndicator(_currentRoomId!);
    }
  }

  void _onMessageReceived(ChatMessage message) {
    if (message.status != MessageStatus.read &&
        message.roomId.isNotEmpty &&
        message.roomId != _currentRoomId) {
      print(
        '⚠ Ignoring message for room ${message.roomId}, currently in $_currentRoomId',
      );
      return;
    }

    if (message.isBot && message.status == MessageStatus.streaming) {
      _typingIndicator = null;
    }

    if (message.status == MessageStatus.read) {
      print('📖 Received read receipt for message: ${message.id}');
      final existingIndex =
          _messages.indexWhere((item) => item.id == message.id);
      if (existingIndex != -1) {
        if (_messages[existingIndex].status != MessageStatus.read) {
          _messages[existingIndex] = _messages[existingIndex].copyWith(
            status: MessageStatus.read,
          );
          _notifySafely();
          print('✓ Updated message ${message.id} status to READ');
        }
      } else {
        print(
            '⚠ Message ${message.id} not found in local list for read receipt');
      }
      return;
    }

    if (message.id.startsWith('local_')) {
      _messages.add(message);
    } else {
      final localMessageIndex = _messages.indexWhere(
        (item) =>
            item.id.startsWith('local_') &&
            item.content == message.content &&
            item.userId == message.userId &&
            item.roomId == message.roomId,
      );

      if (localMessageIndex != -1) {
        _messages[localMessageIndex] = _messages[localMessageIndex].copyWith(
          id: message.id,
          status: MessageStatus.delivered,
        );
      } else if (!_messages.any((item) => item.id == message.id)) {
        _messages.add(message);
      }
    }

    _error = null;
    _notifySafely();
  }

  void _onError(dynamic error) {
    _error = error.toString();
    _notifySafely();
  }

  void markAsRead(String messageId) {
    if (_currentRoomId == null) return;

    final index = _messages.indexWhere((item) => item.id == messageId);
    if (index != -1) {
      if (_messages[index].status != MessageStatus.read &&
          _messages[index].userId != _currentUserId) {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.read,
        );
        chatService.sendMarkRead(_currentRoomId!, messageId);
        _notifySafely();
      }
    }
  }

  void clearMessages() {
    _messages.clear();
    _error = null;
    _notifySafely();
  }

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
      } catch (error) {
        _error = 'Reconnection failed: $error';
        _isLoading = false;
        _notifySafely();
      }
    }
  }

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
