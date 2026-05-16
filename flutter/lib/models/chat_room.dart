/// Chat Room model
class ChatRoom {
  final String id;
  final String name;
  final String description;
  final String roomType; // 'GROUP' or 'DM'
  final int creatorId;
  final String creatorUsername;
  final List<dynamic> participants;
  final int participantsCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? lastMessage;
  final DateTime lastMessageTimestamp;
  final int? lastMessageSenderId;
  final int unreadCount;

  // New fields for DMs
  final String otherParticipantName;
  final int? otherParticipantId;
  final String? otherParticipantAvatar;

  ChatRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.roomType,
    required this.creatorId,
    required this.creatorUsername,
    this.participants = const [],
    required this.participantsCount,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    required this.lastMessageTimestamp,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.otherParticipantName = '',
    this.otherParticipantId,
    this.otherParticipantAvatar,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final rawId = _extractRoomId(json);
    final roomId = rawId?.toString() ?? '';

    return ChatRoom(
      id: roomId,
      name: (json['name'] as String?) ??
          (json['room_name'] as String?) ??
          (json['title'] as String?) ??
          'Chat',
      description: json['description'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'GROUP',
      creatorId: json['creator_id'] as int? ?? 0,
      creatorUsername: json['creator_username'] as String? ?? '',
      participants: json['participants'] as List<dynamic>? ?? [],
      participantsCount: json['participants_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      lastMessage: json['last_message'] as String?,
      lastMessageTimestamp: json['last_message_timestamp'] != null
          ? _parseDateTime(json['last_message_timestamp']) ?? DateTime.now()
          : (_parseDateTime(json['updated_at']) ?? DateTime.now()),
      lastMessageSenderId: json['last_message_sender_id'] as int?,
      unreadCount: json['unread_count'] as int? ?? 0,
      otherParticipantName: json['other_participant_name'] as String? ?? '',
      otherParticipantId: json['other_participant_id'] as int?,
      otherParticipantAvatar: json['other_participant_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'room_type': roomType,
        'creator_id': creatorId,
        'creator_username': creatorUsername,
        'participants': participants,
        'participants_count': participantsCount,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_message': lastMessage,
        'last_message_timestamp': lastMessageTimestamp.toIso8601String(),
        'last_message_sender_id': lastMessageSenderId,
        'unread_count': unreadCount,
        'other_participant_name': otherParticipantName,
        'other_participant_id': otherParticipantId,
        'other_participant_avatar': otherParticipantAvatar,
      };

  ChatRoom copyWith({
    String? id,
    String? name,
    String? description,
    String? roomType,
    int? creatorId,
    String? creatorUsername,
    List<dynamic>? participants,
    int? participantsCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    int? lastMessageSenderId,
    int? unreadCount,
    String? otherParticipantName,
    int? otherParticipantId,
    String? otherParticipantAvatar,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      roomType: roomType ?? this.roomType,
      creatorId: creatorId ?? this.creatorId,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      participants: participants ?? this.participants,
      participantsCount: participantsCount ?? this.participantsCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      otherParticipantName: otherParticipantName ?? this.otherParticipantName,
      otherParticipantId: otherParticipantId ?? this.otherParticipantId,
      otherParticipantAvatar:
          otherParticipantAvatar ?? this.otherParticipantAvatar,
    );
  }

  @override
  String toString() => 'ChatRoom(id: $id, name: $name, type: $roomType)';
}

/// Response for list of rooms
class RoomsListResponse {
  final List<ChatRoom> results;
  final int count;

  RoomsListResponse({
    required this.results,
    required this.count,
  });

  factory RoomsListResponse.fromJson(Map<String, dynamic> json) {
    return RoomsListResponse(
      results: (json['results'] as List<dynamic>)
          .map((e) => ChatRoom.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int? ?? (json['results'] as List<dynamic>).length,
    );
  }
}

/// Response for creating/adding members
class OperationResponse {
  final String message;
  final dynamic data; // User object or operation result

  OperationResponse({
    required this.message,
    this.data,
  });

  factory OperationResponse.fromJson(Map<String, dynamic> json) {
    return OperationResponse(
      message: json['message'] as String,
      data: json['user'] ?? json['room'] ?? json['data'],
    );
  }
}

dynamic _extractRoomId(Map<String, dynamic> json) {
  final directId =
      json['id'] ?? json['room_id'] ?? json['roomId'] ?? json['pk'];
  if (directId != null) {
    return directId;
  }

  final nestedRoom = json['room'];
  if (nestedRoom is Map) {
    return _extractRoomId(Map<String, dynamic>.from(nestedRoom));
  }

  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}
