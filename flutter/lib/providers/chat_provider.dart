/// Chat State Management using Provider
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService chatService;

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

  ChatProvider({required this.chatService}) {
    // Listen to WebSocket messages
    chatService.messageStream.listen(
      _onMessageReceived,
      onError: _onError,
    );

    // Listen to connection status
    chatService.connectionStream.listen(
      (isConnected) {
        _isConnected = isConnected;
        notifyListeners();
      },
    );
  }

  /// Initialize chat provider with room and user info
  Future<void> initialize({
    required String roomId,
    required int userId,
    required String username,
  }) async {
    _currentRoomId = roomId;
    _currentUserId = userId;
    _currentUsername = username;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await chatService.connectWebSocket(roomId: roomId);
      _isConnected = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to connect: $e';
      _isLoading = false;
      notifyListeners();
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
    notifyListeners();

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

    _messages.add(message);
    _error = null;
    notifyListeners();
  }

  /// Handle errors
  void _onError(dynamic error) {
    _error = error.toString();
    notifyListeners();
  }

  /// Mark message as read
  void markAsRead(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        status: MessageStatus.delivered,
      );
      notifyListeners();
    }
  }

  /// Clear messages
  void clearMessages() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  /// Reconnect WebSocket
  Future<void> reconnect() async {
    if (_currentRoomId != null) {
      try {
        _isLoading = true;
        _error = null;
        notifyListeners();

        await chatService.connectWebSocket(roomId: _currentRoomId!);
        _isConnected = true;
        _isLoading = false;
        notifyListeners();
      } catch (e) {
        _error = 'Reconnection failed: $e';
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    chatService.dispose();
    super.dispose();
  }
}
