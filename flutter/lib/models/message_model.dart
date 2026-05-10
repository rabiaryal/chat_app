import 'chat_message.dart';

/// Persistence-friendly message model for Hive cache.
class MessageModel {
  final String id;
  final String text;
  final DateTime timestamp;
  final String roomId;
  final int userId;
  final String username;
  final bool isBot;
  final MessageType type;
  final MessageStatus status;
  final bool isSeen;

  const MessageModel({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.roomId,
    required this.userId,
    required this.username,
    this.isBot = false,
    this.type = MessageType.text,
    this.status = MessageStatus.delivered,
    this.isSeen = false,
  });

  factory MessageModel.fromChatMessage(ChatMessage message) {
    return MessageModel(
      id: message.id,
      text: message.content,
      timestamp: message.timestamp,
      roomId: message.roomId,
      userId: message.userId,
      username: message.username,
      isBot: message.isBot,
      type: message.type,
      status: message.status,
      isSeen: message.status == MessageStatus.read,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? json['content']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      roomId: json['room_id']?.toString() ?? '',
      userId: _parseInt(json['user_id']) ?? 0,
      username: json['username']?.toString() ?? 'Unknown',
      isBot: json['is_bot'] == true,
      type: _parseMessageType(json['message_type']?.toString() ?? 'TEXT'),
      status: json['is_read'] == true 
          ? MessageStatus.read 
          : _parseMessageStatus(json['status']?.toString() ?? 'delivered'),
      isSeen: json['is_seen'] == true || json['is_read'] == true,
    );
  }

  ChatMessage toChatMessage() {
    return ChatMessage(
      id: id,
      content: text,
      userId: userId,
      username: username,
      roomId: roomId,
      type: type,
      status: isSeen ? MessageStatus.read : status,
      isBot: isBot,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'room_id': roomId,
      'user_id': userId,
      'username': username,
      'is_bot': isBot,
      'message_type': _messageTypeToString(type),
      'status': status.name,
      'is_read': isSeen || status == MessageStatus.read,
      'is_seen': isSeen,
    };
  }

  static MessageType _parseMessageType(String type) {
    switch (type.toUpperCase()) {
      case 'IMAGE':
        return MessageType.image;
      case 'AI':
      case 'AI_RESPONSE':
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

  static MessageStatus _parseMessageStatus(String status) {
    switch (status) {
      case 'read':
        return MessageStatus.read;
      case 'delivered':
        return MessageStatus.delivered;
      case 'sending':
        return MessageStatus.sending;
      case 'streaming':
        return MessageStatus.streaming;
      case 'error':
        return MessageStatus.error;
      default:
        return MessageStatus.delivered;
    }
  }
}
