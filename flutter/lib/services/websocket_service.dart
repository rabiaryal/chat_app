/// WebSocket Service for real-time chat with Django Channels
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/src/exception.dart';
import 'dart:convert';
import 'dart:async';

class Message {
  final String type;
  final String? content;
  final int? userId;
  final String? username;
  final String? messageId;
  final DateTime timestamp;
  final Map<String, dynamic>? additionalData;

  Message({
    required this.type,
    this.content,
    this.userId,
    this.username,
    this.messageId,
    required this.timestamp,
    this.additionalData,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      type: json['type'] ?? 'unknown',
      content: json['content'],
      userId: json['user_id'],
      username: json['username'],
      messageId: json['message_id'],
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      additionalData: json,
    );
  }
}

class WebSocketService {
  final String baseUrl;
  late WebSocketChannel? _channel;
  late StreamController<Message> _messageController;
  late String _roomId;

  WebSocketService({this.baseUrl = 'ws://localhost:8000'}) {
    _messageController = StreamController<Message>.broadcast();
    _channel = null;
  }

  /// Connect to WebSocket chat room
  Future<void> connect({required String roomId, required String token}) async {
    try {
      _roomId = roomId;

      final wsUrl = Uri.parse('$baseUrl/ws/chat/$roomId/?token=$token');
      _channel = WebSocketChannel.connect(wsUrl);

      // Listen to incoming messages
      _channel!.stream.listen(
        (dynamic message) {
          try {
            final jsonData = jsonDecode(message as String);
            final msg = Message.fromJson(jsonData);
            _messageController.add(msg);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onError: (error) {
          if (error is WebSocketChannelException) {
            print('WebSocket channel error: ${error.message}');
            _messageController
                .addError(WebSocketChannelException.from(error.inner ?? error));
          } else {
            print('WebSocket error: $error');
            _messageController.addError(error);
          }
        },
        onDone: () {
          print('WebSocket connection closed');
          disconnect();
        },
      );

      print('WebSocket connected to room: $roomId');
    } catch (e) {
      if (e is WebSocketChannelException) {
        throw WebSocketChannelException(
            'WebSocket connection error: ${e.message}');
      }
      throw WebSocketChannelException('WebSocket connection error: $e');
    }
  }

  /// Send a text message
  void sendTextMessage(String content) {
    if (_channel == null) {
      throw WebSocketChannelException('WebSocket not connected');
    }

    final message = {'type': 'text_message', 'content': content};

    _channel!.sink.add(jsonEncode(message));
  }

  /// Request AI response
  void requestAIResponse(String content) {
    if (_channel == null) {
      throw WebSocketChannelException('WebSocket not connected');
    }

    final message = {'type': 'ai_request', 'content': content};

    _channel!.sink.add(jsonEncode(message));
  }

  /// Send typing indicator
  void sendTypingIndicator() {
    if (_channel == null) {
      throw WebSocketChannelException('WebSocket not connected');
    }

    final message = {'type': 'typing'};

    _channel!.sink.add(jsonEncode(message));
  }

  /// Send a custom message
  void sendMessage(Map<String, dynamic> messageData) {
    if (_channel == null) {
      throw WebSocketChannelException('WebSocket not connected');
    }

    _channel!.sink.add(jsonEncode(messageData));
  }

  /// Stream of incoming messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Disconnect WebSocket
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  /// Check if connected
  bool isConnected() => _channel != null;

  /// Get current room ID
  String get roomId => _roomId;
}

/// Chat message model for local storage
class ChatMessage {
  final String id;
  final String roomId;
  final int userId;
  final String username;
  final String content;
  final String type;
  final DateTime timestamp;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromMessage(Message msg, String roomId) {
    return ChatMessage(
      id: msg.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      userId: msg.userId ?? 0,
      username: msg.username ?? 'Unknown',
      content: msg.content ?? '',
      type: msg.type,
      timestamp: msg.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'userId': userId,
      'username': username,
      'content': content,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      roomId: json['roomId'],
      userId: json['userId'],
      username: json['username'],
      content: json['content'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
    );
  }
}
