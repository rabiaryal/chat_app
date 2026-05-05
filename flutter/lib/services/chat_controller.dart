import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';
import 'hive_token_storage.dart';

/// ChatController: Manages the lazy room creation flow from friend → chat
///
/// SEQUENCE:
/// 1. User views friend profile, clicks "Message"
/// 2. ChatController.initializeChat(targetUserId) is called
/// 3. Controller sends: POST /api/chat/initialize/ { target_user_id }
/// 4. Django checks:
///    - Are they friends? (Friendship.status == ACCEPTED)
///    - Does room exist?
///    - If not, create it
/// 5. Returns room_id + empty/existing messages
/// 6. Flutter navigates to ChatScreen with room_id
///
/// STATES:
/// - NotFriendsYet: Show "Add Friend" button
/// - FriendshipPending: Show "Request Pending" (disabled)
/// - FriendshipAccepted: Show "Message" button (enabled)
/// - Loading: Show spinner while room is being created
/// - Ready: ChatScreen opens
class ChatController {
  final ApiService apiService;
  final HiveTokenStorage tokenStorage;

  ChatController({
    required this.apiService,
    HiveTokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? HiveTokenStorage();

  /// Initialize chat with another user (lazy room creation)
  ///
  /// Flow:
  /// 1. POST /api/chat/initialize/ with target_user_id
  /// 2. Django verifies friendship is ACCEPTED
  /// 3. Django checks if room exists
  /// 4. If not, creates room (lazy creation)
  /// 5. Returns room_id
  ///
  /// Throws:
  /// - Exception if not friends (403)
  /// - Exception if user not found (404)
  /// - Exception if network error
  Future<ChatInitResponse> initializeChat({required int targetUserId}) async {
    try {
      final accessToken = tokenStorage.getAccessToken();
      if (accessToken == null) {
        throw Exception('No access token available');
      }

      final url = Uri.parse('${apiService.baseUrl}/api/v1/chat/initialize/');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'target_user_id': targetUserId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print(
            '✓ Chat initialized: room_id=${data['room_id']}, created=${data['created']}');
        return ChatInitResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw FriendshipException(
          message: data['error'] ?? 'You are not friends yet',
          friendshipStatus: data['friendship_status'] ?? 'UNKNOWN',
        );
      } else if (response.statusCode == 404) {
        throw Exception('User not found');
      } else {
        throw Exception('Failed to initialize chat: ${response.body}');
      }
    } catch (e) {
      print('✗ Chat initialization error: $e');
      rethrow;
    }
  }

  /// Send a friend request to another user
  ///
  /// POST /api/friendship/request/ { target_user_id }
  Future<void> sendFriendRequest({required int targetUserId}) async {
    try {
      final accessToken = tokenStorage.getAccessToken();
      if (accessToken == null) {
        throw Exception('No access token available');
      }

      final url = Uri.parse('${apiService.baseUrl}/api/v1/friendship/request/');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'target_user_id': targetUserId,
        }),
      );

      if (response.statusCode == 201) {
        print('✓ Friend request sent');
      } else {
        throw Exception('Failed to send friend request: ${response.body}');
      }
    } catch (e) {
      print('✗ Friend request error: $e');
      rethrow;
    }
  }

  /// Check friendship status with another user
  ///
  /// Queries the list of friends and looks for the target user
  Future<FriendshipStatus> checkFriendshipStatus({
    required int targetUserId,
  }) async {
    try {
      final accessToken = tokenStorage.getAccessToken();
      if (accessToken == null) {
        throw Exception('No access token available');
      }

      final url = Uri.parse('${apiService.baseUrl}/api/v1/friends/');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final friends = jsonDecode(response.body) as List;

        // Check if target user is in friends list
        final isFriend = friends.any((friend) => friend['id'] == targetUserId);

        if (isFriend) {
          return FriendshipStatus.accepted;
        } else {
          // Default to not friends yet (could be pending, but we return not friends)
          return FriendshipStatus.notFriends;
        }
      } else {
        throw Exception('Failed to fetch friends list: ${response.body}');
      }
    } catch (e) {
      print('✗ Friendship status check error: $e');
      return FriendshipStatus.notFriends; // Default to not friends on error
    }
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
  notFriends, // No friendship or request
  pending, // Friend request sent or received
  accepted, // Friends
  blocked, // Blocked
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
