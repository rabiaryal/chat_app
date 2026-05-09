/// Chat Room model
class ChatRoom {
  final String id;
  final String name;
  final String description;
  final String roomType; // 'GROUP' or 'DIRECT'
  final int creatorId;
  final String creatorUsername;
  final List<dynamic>
      participants; // Can contain full User objects or just user IDs
  final int participantsCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? lastMessage;
  final DateTime lastMessageTimestamp;

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
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'GROUP',
      creatorId: json['creator_id'] as int? ?? 0,
      creatorUsername: json['creator_username'] as String? ?? '',
      participants: json['participants'] as List<dynamic>? ?? [],
      participantsCount: json['participants_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageTimestamp: json['last_message_timestamp'] != null
          ? DateTime.parse(json['last_message_timestamp'] as String)
          : DateTime.parse(json['updated_at'] as String),
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
      count: json['count'] as int,
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
