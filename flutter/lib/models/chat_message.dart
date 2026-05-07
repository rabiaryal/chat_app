/// Chat Message Model with streaming support and status tracking
import 'package:equatable/equatable.dart';

enum MessageStatus { sending, streaming, delivered, read, error }

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
  final bool isSecure;
  final String? encryptedPayload;
  final String? encryptedKey;
  final String? iv;

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
    this.isSecure = false,
    this.encryptedPayload,
    this.encryptedKey,
    this.iv,
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
    bool? isSecure,
    String? encryptedPayload,
    String? encryptedKey,
    String? iv,
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
      isSecure: isSecure ?? this.isSecure,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      encryptedKey: encryptedKey ?? this.encryptedKey,
      iv: iv ?? this.iv,
    );
  }

  /// Convert from WebSocket message
  factory ChatMessage.fromWebSocketMessage(
    Map<String, dynamic> data,
    String roomId,
  ) {
    final bool isSecure = data['type'] == 'secure_message';
    return ChatMessage(
      id: data['message_id']?.toString() ??
          data['timestamp']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      content: isSecure 
          ? '[Secure Message]' 
          : (data['content']?.toString() ?? data['text']?.toString() ?? ''),
      userId: data['user_id'] ?? data['sender_id'] ?? 0,
      username: data['username'] ?? data['sender_username'] ?? 'Unknown',
      roomId: roomId,
      type: _parseMessageType(data['message_type'] ?? 'TEXT'),
      status: MessageStatus.delivered,
      isBot: data['is_bot'] ?? false,
      timestamp: DateTime.parse(
        data['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      isSecure: isSecure,
      encryptedPayload: data['encrypted_payload'],
      encryptedKey: data['encrypted_key'],
      iv: data['iv'],
    );
  }

  /// Convert from API or cache JSON
  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? fallbackRoomId,
  }) {
    final messageType = json['message_type']?.toString() ?? 'TEXT';
    final roomValue = json['room']?.toString() ??
        json['room_id']?.toString() ??
        fallbackRoomId ??
        '';

    return ChatMessage(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content']?.toString() ?? json['text']?.toString() ?? '',
      userId: _parseInt(json['sender']) ?? _parseInt(json['user_id']) ?? 0,
      username: json['sender_username']?.toString() ??
          json['username']?.toString() ??
          'Unknown',
      roomId: roomValue,
      type: _parseMessageType(messageType),
      status: json['is_read'] == true ? MessageStatus.read : MessageStatus.delivered,
      isBot: json['is_bot'] == true || messageType == 'AI_RESPONSE',
      timestamp: DateTime.tryParse(
            json['created_at']?.toString() ??
                json['timestamp']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      isSecure: json['is_secure'] ?? false,
      encryptedPayload: json['encrypted_payload'],
      encryptedKey: json['encrypted_key'],
      iv: json['iv'],
    );
  }

  /// Convert to a JSON payload for persistence or transport
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'user_id': userId,
      'username': username,
      'room_id': roomId,
      'message_type': _messageTypeToString(type),
      'status': status.name,
      'is_bot': isBot,
      'timestamp': timestamp.toIso8601String(),
      'avatar_url': avatarUrl,
      'image_url': imageUrl,
      'error_message': errorMessage,
      'is_secure': isSecure,
      'encrypted_payload': encryptedPayload,
      'encrypted_key': encryptedKey,
      'iv': iv,
    };
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
    switch (type.toUpperCase()) {
      case 'IMAGE':
        return MessageType.image;
      case 'AI_RESPONSE':
      case 'AI':
        return MessageType.ai;
      default:
        return MessageType.text;
    }
  }

  static String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'IMAGE';
      case MessageType.ai:
        return 'AI_RESPONSE';
      case MessageType.text:
        return 'TEXT';
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
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
        isSecure,
        encryptedPayload,
        encryptedKey,
        iv,
      ];
}
