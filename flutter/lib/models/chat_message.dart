/// Chat Message Model with streaming support and status tracking
import 'package:equatable/equatable.dart';

enum MessageStatus { sending, streaming, delivered, error }

enum MessageType { text, image, ai }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final int userId;
  final String username;
  final String roomId;
  final MessageType type;
  final MessageStatus status;
  final bool isBot;
  final DateTime timestamp;
  final String? avatarUrl;
  final String? imageUrl;
  final String? errorMessage;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.userId,
    required this.username,
    required this.roomId,
    this.type = MessageType.text,
    this.status = MessageStatus.delivered,
    this.isBot = false,
    required this.timestamp,
    this.avatarUrl,
    this.imageUrl,
    this.errorMessage,
  });

  /// Copy with modifications
  ChatMessage copyWith({
    String? id,
    String? content,
    int? userId,
    String? username,
    String? roomId,
    MessageType? type,
    MessageStatus? status,
    bool? isBot,
    DateTime? timestamp,
    String? avatarUrl,
    String? imageUrl,
    String? errorMessage,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      roomId: roomId ?? this.roomId,
      type: type ?? this.type,
      status: status ?? this.status,
      isBot: isBot ?? this.isBot,
      timestamp: timestamp ?? this.timestamp,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convert from WebSocket message
  factory ChatMessage.fromWebSocketMessage(
    Map<String, dynamic> data,
    String roomId,
  ) {
    return ChatMessage(
      id: data['message_id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      content: data['content'] ?? '',
      userId: data['user_id'] ?? 0,
      username: data['username'] ?? 'Unknown',
      roomId: roomId,
      type: _parseMessageType(data['message_type'] ?? 'TEXT'),
      status: MessageStatus.delivered,
      isBot: data['is_bot'] ?? false,
      timestamp: DateTime.parse(
        data['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Convert from AI response chunk
  factory ChatMessage.fromAIChunk(
    String chunkContent,
    String roomId,
  ) {
    return ChatMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      content: chunkContent,
      userId: 0,
      username: 'AI Assistant',
      roomId: roomId,
      type: MessageType.ai,
      status: MessageStatus.streaming,
      isBot: true,
      timestamp: DateTime.now(),
    );
  }

  /// Create a local message being sent
  factory ChatMessage.local({
    required String content,
    required int userId,
    required String username,
    required String roomId,
    bool isBot = false,
  }) {
    return ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      userId: userId,
      username: username,
      roomId: roomId,
      status: MessageStatus.sending,
      isBot: isBot,
      timestamp: DateTime.now(),
    );
  }

  static MessageType _parseMessageType(String type) {
    switch (type) {
      case 'IMAGE':
        return MessageType.image;
      case 'AI_RESPONSE':
        return MessageType.ai;
      default:
        return MessageType.text;
    }
  }

  @override
  List<Object?> get props => [
        id,
        content,
        userId,
        username,
        roomId,
        type,
        status,
        isBot,
        timestamp,
        avatarUrl,
        imageUrl,
        errorMessage,
      ];
}

/// Room info model
class ChatRoom extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String roomType;
  final List<Map<String, dynamic>> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatRoom({
    required this.id,
    required this.name,
    this.description,
    required this.roomType,
    this.participants = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      roomType: json['room_type'],
      participants: List<Map<String, dynamic>>.from(json['participants'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, description, roomType, participants, createdAt, updatedAt];
}
