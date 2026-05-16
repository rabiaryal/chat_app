import 'package:hive_flutter/hive_flutter.dart';
import '../api_service.dart';
import '../storage/hive_token_storage.dart';

/// ChatController: Manages the lazy room creation flow from friend → chat
///
/// SEQUENCE:
/// 1. User views friend profile, clicks "Message"
/// 2. ChatController.initializeChat(targetUserId) is called
/// 3. Controller sends: POST /api/chat/initialize/ { target_user_id }
/// 4. Django checks: Are they friends? Does room exist? Creates if not.
/// 5. Returns room_id + empty/existing messages
/// 6. Flutter navigates to ChatScreen with room_id
class ChatController {
  final ApiService apiService;
  final HiveTokenStorage tokenStorage;

  ChatController({
    required this.apiService,
    HiveTokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? HiveTokenStorage();

  String _cacheBoxName({String? userId}) {
    final scope = userId ?? tokenStorage.getCurrentUserId();
    return scope == null
        ? 'chat_rooms_cache_global'
        : 'chat_rooms_cache_$scope';
  }

  /// Initialize chat with another user (lazy room creation)
  Future<ChatInitResponse> initializeChat({required int targetUserId}) async {
    final cacheBox = await Hive.openBox<Map>(_cacheBoxName());

    final result = await apiService.getOrCreateDirectRoom(targetUserId).run();

    return result.fold(
      (failure) async {
        print('✗ Chat initialization error: ${failure.message}');

        final cachedData = cacheBox.get(targetUserId.toString());
        if (cachedData != null) {
          print('ℹ Using cached room info for user $targetUserId');
          return ChatInitResponse.fromJson(
              Map<String, dynamic>.from(cachedData));
        }

        throw Exception(failure.message);
      },
      (room) async {
        final chatInitResponse = ChatInitResponse(
          roomId: room.id,
          created: false,
          roomName: room.name,
          messages: [],
          message: 'Room initialized',
        );

        await cacheBox.put(targetUserId.toString(), {
          'room_id': room.id,
          'room_name': room.name,
        });

        print('✓ Chat initialized: room_id=${room.id}');
        return chatInitResponse;
      },
    );
  }

  /// Send a friend request to another user
  Future<void> sendFriendRequest({required int targetUserId}) async {
    final result =
        await apiService.sendFriendRequest(targetUserId: targetUserId).run();

    result.fold(
      (failure) {
        print('✗ Friend request error: ${failure.message}');
        throw Exception(failure.message);
      },
      (_) => print('✓ Friend request sent'),
    );
  }

  /// Check friendship status with another user
  Future<FriendshipStatus> checkFriendshipStatus({
    required int targetUserId,
  }) async {
    final result = await apiService.getFriends(limit: 100).run();

    return result.fold(
      (failure) async {
        print('✗ Friendship status check error: ${failure.message}');

        try {
          final cacheBox = await Hive.openBox<Map>(_cacheBoxName());
          if (cacheBox.containsKey(targetUserId.toString())) {
            print('ℹ Using cached friendship status for user $targetUserId');
            return FriendshipStatus.accepted;
          }
        } catch (cacheError) {
          print('Error checking room cache: $cacheError');
        }

        return FriendshipStatus.notFriends;
      },
      (friends) {
        final isFriend = friends.any((friend) => friend.id == targetUserId);
        return isFriend
            ? FriendshipStatus.accepted
            : FriendshipStatus.notFriends;
      },
    );
  }

  /// Clear the cached room mappings for a specific user.
  Future<void> clearCachedRoomsForUser(String userId) async {
    final cacheBox = await Hive.openBox<Map>(_cacheBoxName(userId: userId));
    await cacheBox.clear();
  }
}

/// Response from POST /api/chat/initialize/
class ChatInitResponse {
  final String roomId;
  final bool created;
  final String roomName;
  final List<Map<String, dynamic>> messages;
  final String message;

  ChatInitResponse({
    required this.roomId,
    required this.created,
    required this.roomName,
    required this.messages,
    required this.message,
  });

  factory ChatInitResponse.fromJson(Map<String, dynamic> json) {
    return ChatInitResponse(
      roomId: json['room_id'],
      created: json['created'] ?? false,
      roomName: json['room_name'] ?? 'Chat',
      messages: List<Map<String, dynamic>>.from(json['messages'] ?? []),
      message: json['message'] ?? '',
    );
  }
}

/// Friendship status between current user and target user
enum FriendshipStatus {
  notFriends,
  pending,
  accepted,
  blocked,
}

/// Exception thrown when friendship status prevents chat initialization
class FriendshipException implements Exception {
  final String message;
  final String friendshipStatus;

  FriendshipException({
    required this.message,
    required this.friendshipStatus,
  });

  @override
  String toString() => 'FriendshipException: $message ($friendshipStatus)';
}
