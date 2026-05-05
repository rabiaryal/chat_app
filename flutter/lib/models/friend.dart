/// Friend model for displaying user friends
class Friend {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? avatar;

  Friend({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.isOnline = false,
    this.lastSeen,
    this.avatar,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      avatar: json['avatar'] as String?,
    );
  }

  String get displayName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }
    return username;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'avatar': avatar,
      };
}

/// Friend Request model
class FriendRequest {
  final int id;
  final int fromUserId;
  final String fromUsername;
  final String fromFirstName;
  final String fromLastName;
  final int toUserId;
  final String toUsername;
  final String status; // 'PENDING', 'ACCEPTED', 'REJECTED'
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromFirstName,
    required this.fromLastName,
    required this.toUserId,
    required this.toUsername,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int,
      fromUserId: json['from_user_id'] as int,
      fromUsername: json['from_username'] as String,
      fromFirstName: json['from_first_name'] as String? ?? '',
      fromLastName: json['from_last_name'] as String? ?? '',
      toUserId: json['to_user_id'] as int,
      toUsername: json['to_username'] as String,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
    );
  }

  String get requesterDisplayName {
    if (fromFirstName.isNotEmpty && fromLastName.isNotEmpty) {
      return '$fromFirstName $fromLastName';
    } else if (fromFirstName.isNotEmpty) {
      return fromFirstName;
    } else if (fromLastName.isNotEmpty) {
      return fromLastName;
    }
    return fromUsername;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'from_user_id': fromUserId,
        'from_username': fromUsername,
        'to_user_id': toUserId,
        'to_username': toUsername,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'responded_at': respondedAt?.toIso8601String(),
      };
}
