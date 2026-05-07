/// API Service using Dio with automatic token management
import 'package:dio/dio.dart';
import 'hive_token_storage.dart';
import 'dio_client.dart';
import 'token_manager.dart';
import '../models/user.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/friend.dart';

class ApiService {
  final String baseUrl;
  final HiveTokenStorage tokenStorage;
  late final DioClient _dioClient;
  late final TokenManager tokenManager;

  Dio get dio => _dioClient.dio;

  ApiService({
    this.baseUrl = 'http://192.168.1.65:8000',
    HiveTokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? HiveTokenStorage() {
    _dioClient = DioClient(
      tokenStorage: this.tokenStorage,
      baseUrl: baseUrl,
    );
    tokenManager = TokenManager(tokenStorage: this.tokenStorage);
  }

  /// 1. Register a new user
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await dio.post(
        '/api/v1/auth/register/',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': password,
          'first_name': firstName ?? '',
          'last_name': lastName ?? '',
        },
      );

      if (response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(response.data);
        // Save tokens to Hive storage
        await tokenStorage.saveTokens(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
        );
        print('✓ Registration successful, tokens saved');
        return authResponse;
      } else {
        throw Exception(
          response.data['detail'] ??
              response.data['error'] ??
              'Registration failed',
        );
      }
    } on DioException catch (e) {
      print('✗ Registration error: $e');
      throw Exception(e.message ?? 'Registration failed');
    }
  }

  /// 2. Login user and get JWT tokens
  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '/api/v1/auth/login/',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        // Save tokens to Hive storage
        await tokenStorage.saveTokens(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
        );
        print('✓ Login successful, tokens saved to Hive');
        return authResponse;
      } else {
        throw Exception(
          response.data['detail'] ?? response.data['error'] ?? 'Login failed',
        );
      }
    } on DioException catch (e) {
      print('✗ Login error: $e');
      throw Exception(e.message ?? 'Login failed');
    }
  }

  /// 3. Logout - invalidate refresh token
  Future<void> logout() async {
    try {
      final refreshToken = tokenStorage.getRefreshToken();

      try {
        if (refreshToken != null) {
          print('📤 Sending logout request with refresh token...');
          await dio.post(
            '/api/v1/auth/logout/',
            data: {'refresh': refreshToken},
          );
          print('✓ Logout API call successful');
        } else {
          print('⚠ No refresh token available, logging out locally');
        }
      } catch (e) {
        print('⚠ Logout API call failed, but clearing tokens anyway: $e');
        // Continue with local logout even if API fails
      }

      // Clear tokens locally
      await tokenStorage.clearTokens();
      print('✓ Logout successful, tokens cleared locally');
    } catch (e) {
      print('✗ Logout error: $e');
      rethrow;
    }
  }

  /// 4. Get current user info
  Future<User> getCurrentUser() async {
    // Check if token is available
    if (tokenStorage.getAccessToken() == null) {
      print('✗ getCurrentUser: No access token available');
      throw Exception('Authentication required - please login');
    }

    try {
      final response = await dio.get('/api/v1/user/me/');

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        print('✓ User profile fetched: ${user.username}');
        return user;
      } else {
        throw Exception('Failed to get user profile: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        print('✗ Unauthorized - tokens may have expired');
        throw Exception('Session expired - please login again');
      }
      print('✗ Get user error: $e');
      rethrow;
    }
  }

  /// 5. Change password
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    try {
      final response = await dio.post(
        '/api/v1/auth/change-password/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPasswordConfirm,
        },
      );

      if (response.statusCode == 200) {
        print('✓ Password changed successfully');
        return response.data;
      } else {
        throw Exception('Failed to change password');
      }
    } on DioException catch (e) {
      print('✗ Change password error: $e');
      rethrow;
    }
  }

  /// 6. Delete user account
  Future<Map<String, dynamic>> deleteUserAccount() async {
    try {
      final response = await dio.delete('/api/v1/user/delete/');

      if (response.statusCode == 200) {
        await tokenStorage.clearTokens();
        print('✓ Account deleted successfully');
        return response.data;
      } else {
        throw Exception('Failed to delete account');
      }
    } on DioException catch (e) {
      print('✗ Delete account error: $e');
      rethrow;
    }
  }

  /// 7. Restore session from stored tokens
  Future<bool> restoreSession() async {
    try {
      final accessToken = tokenStorage.getAccessToken();
      if (accessToken == null) {
        print('⚠ No tokens found in Hive storage');
        return false;
      }

      print('✓ Session restored from Hive storage');
      return true;
    } catch (e) {
      print('✗ Error restoring session: $e');
      return false;
    }
  }

  /// 8. Get token status for debugging
  Map<String, dynamic> getTokenStatus() {
    final tokens = tokenStorage.getAllTokens();
    return {
      'hasToken': tokens['accessToken'] != null,
      'accessToken': tokens['accessToken'] != null ? '***' : 'null',
      'refreshToken': tokens['refreshToken'] != null ? '***' : 'null',
    };
  }

  // ============== FRIEND-RELATED ENDPOINTS ==============

  /// Get list of friends
  Future<List<User>> getFriends({int page = 1, int limit = 10}) async {
    // Check if token is available
    if (tokenStorage.getAccessToken() == null) {
      print('✗ getFriends: No access token available');
      throw Exception('Authentication required - please login');
    }

    try {
      final response = await dio.get(
        '/api/v1/friends/',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final rawFriends = data is List 
            ? data 
            : (data['results'] as List? ?? []);
            
        final friends = rawFriends
            .map((friend) => User.fromJson(friend))
            .toList();
        print('✓ Loaded ${friends.length} friends (page $page)');
        return friends;
      } else if (response.statusCode == 401) {
        print('✗ Unauthorized - tokens may have expired');
        throw Exception('Session expired - please login again');
      } else {
        throw Exception('Failed to fetch friends: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('✗ Get friends error: $e');
      rethrow;
    }
  }

  /// Get all available users
  Future<List<User>> getAllUsers() async {
    // Check if token is available before making request
    if (tokenStorage.getAccessToken() == null) {
      print(
          '⚠ getAllUsers attempted without access token - tokens may not be loaded');
      return [];
    }

    try {
      final response = await dio.get(
        '/api/v1/user/search/',
        queryParameters: {'search': ''}, // Empty search to get all users
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final results = data is List
            ? data.map((user) => User.fromJson(user)).toList()
            : (data['results'] as List)
                .map((user) => User.fromJson(user))
                .toList();
        print('✓ Loaded ${results.length} available users');
        return results;
      } else if (response.statusCode == 401) {
        print('✗ Unauthorized - tokens may have expired');
        return [];
      } else {
        throw Exception('Failed to fetch users: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('✗ Get all users error: $e');
      return [];
    }
  }

  /// Get suggested users (non-friends)
  Future<List<User>> getSuggestedUsers({int page = 1, int limit = 5}) async {
    if (tokenStorage.getAccessToken() == null) {
      print('⚠ getSuggestedUsers attempted without access token - tokens may not be loaded');
      return [];
    }

    try {
      final response = await dio.get(
        '/api/v1/user/suggested/',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final results = data is List
            ? data.map((user) => User.fromJson(user)).toList()
            : (data['results'] as List)
                .map((user) => User.fromJson(user))
                .toList();
        print('✓ Loaded ${results.length} suggested users');
        return results;
      } else if (response.statusCode == 401) {
        print('✗ Unauthorized - tokens may have expired');
        return [];
      } else {
        throw Exception('Failed to fetch suggested users: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('✗ Get suggested users error: $e');
      return [];
    }
  }

  /// Search for users
  Future<List<User>> searchUsers(String query) async {
    // Check if token is available before making request
    if (tokenStorage.getAccessToken() == null) {
      print(
          '⚠ Search attempted without access token - tokens may not be loaded');
      return [];
    }

    try {
      final response = await dio.get(
        '/api/v1/user/search/',
        queryParameters: {'search': query},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final results = data is List
            ? data.map((user) => User.fromJson(user)).toList()
            : (data['results'] as List)
                .map((user) => User.fromJson(user))
                .toList();
        print('✓ Found ${results.length} users');
        return results;
      } else if (response.statusCode == 401) {
        print('✗ Unauthorized - tokens may have expired');
        return [];
      } else {
        throw Exception('Failed to search users: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('✗ Search users error: $e');
      return [];
    }
  }

  /// Send friend request
  Future<void> sendFriendRequest({required int targetUserId}) async {
    try {
      final response = await dio.post(
        '/api/v1/friendship/request/',
        data: {'target_user_id': targetUserId},
      );

      if (response.statusCode == 201) {
        print('✓ Friend request sent to user $targetUserId');
      } else {
        throw Exception('Failed to send friend request');
      }
    } on DioException catch (e) {
      print('✗ Send friend request error: $e');
      rethrow;
    }
  }

  /// Get incoming friend requests
  Future<List<FriendRequest>> getIncomingFriendRequests() async {
    try {
      final response = await dio.get('/api/v1/friendship/requests/incoming/');

      if (response.statusCode == 200) {
        final requests = (response.data as List)
            .map((req) => FriendRequest.fromJson(req))
            .toList();
        print('✓ Loaded ${requests.length} incoming requests');
        return requests;
      } else {
        throw Exception('Failed to fetch incoming requests');
      }
    } on DioException catch (e) {
      print('✗ Get incoming requests error: $e');
      rethrow;
    }
  }

  /// Get outgoing friend requests
  Future<List<FriendRequest>> getOutgoingFriendRequests() async {
    try {
      final response = await dio.get('/api/v1/friendship/requests/outgoing/');

      if (response.statusCode == 200) {
        final requests = (response.data as List)
            .map((req) => FriendRequest.fromJson(req))
            .toList();
        print('✓ Loaded ${requests.length} outgoing requests');
        return requests;
      } else {
        throw Exception('Failed to fetch outgoing requests');
      }
    } on DioException catch (e) {
      print('✗ Get outgoing requests error: $e');
      rethrow;
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(int requestId) async {
    try {
      final response = await dio.post(
        '/api/v1/friendship/accept/',
        data: {'friendship_id': requestId},
      );

      if (response.statusCode == 200) {
        print('✓ Friend request accepted');
      } else {
        throw Exception('Failed to accept friend request');
      }
    } on DioException catch (e) {
      print('✗ Accept friend request error: $e');
      rethrow;
    }
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(int requestId) async {
    try {
      final response = await dio.post(
        '/api/v1/friendship/reject/',
        data: {'friendship_id': requestId},
      );

      if (response.statusCode == 200) {
        print('✓ Friend request rejected');
      } else {
        throw Exception('Failed to reject friend request');
      }
    } on DioException catch (e) {
      print('✗ Reject friend request error: $e');
      rethrow;
    }
  }

  /// Remove friend
  Future<void> removeFriend(int friendId) async {
    try {
      final response = await dio.delete('/api/v1/friends/$friendId/');

      if (response.statusCode == 204) {
        print('✓ Friend removed');
      } else {
        throw Exception('Failed to remove friend');
      }
    } on DioException catch (e) {
      print('✗ Remove friend error: $e');
      rethrow;
    }
  }

  // ============== ROOM & MESSAGE ENDPOINTS ==============

  /// Get or create a direct message room with a friend (lazy creation)
  Future<ChatRoom> getOrCreateDirectRoom(int friendId) async {
    try {
      final response = await dio.post(
        '/api/v1/rooms/direct/$friendId/',
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final room = ChatRoom.fromJson(response.data);
        print('✓ Direct room ready: ${room.name}');
        return room;
      } else {
        throw Exception('Failed to create/get direct room');
      }
    } on DioException catch (e) {
      print('✗ Get direct room error: $e');
      rethrow;
    }
  }

  /// Get all rooms
  Future<List<ChatRoom>> getRooms() async {
    try {
      final response = await dio.get('/api/v1/rooms/');

      if (response.statusCode == 200) {
        final data = response.data;
        final rawRooms = data is List ? data : (data['results'] as List? ?? []);
        
        final rooms = rawRooms
            .map((room) => ChatRoom.fromJson(room))
            .toList();
        print('✓ Loaded ${rooms.length} rooms');
        return rooms;
      } else {
        throw Exception('Failed to fetch rooms');
      }
    } on DioException catch (e) {
      print('✗ Get rooms error: $e');
      rethrow;
    }
  }

  /// Create a new group chat
  Future<ChatRoom> createGroup({
    required String name,
    String? description,
    required List<int> participantIds,
  }) async {
    try {
      final response = await dio.post(
        '/api/v1/rooms/create-group/',
        data: {
          'name': name,
          'description': description ?? '',
          'participant_ids': participantIds,
        },
      );

      if (response.statusCode == 201) {
        print('✓ Group created: ${response.data['room']['id']}');
        return ChatRoom.fromJson(response.data['room']);
      } else {
        throw Exception('Failed to create group');
      }
    } on DioException catch (e) {
      print('✗ Create group error: $e');
      rethrow;
    }
  }

  /// Leave a group chat
  Future<void> leaveRoom(String roomId) async {
    try {
      final response = await dio.delete('/api/v1/rooms/$roomId/members/');

      if (response.statusCode == 200) {
        print('✓ Left room $roomId');
      } else {
        throw Exception('Failed to leave room');
      }
    } on DioException catch (e) {
      print('✗ Leave room error: $e');
      rethrow;
    }
  }

  /// Get the latest messages in a room.
  Future<List<ChatMessage>> getMessages(
    String roomId, {
    int limit = 20,
  }) async {
    try {
      final response = await dio.get(
        '/api/v1/rooms/$roomId/messages/',
        queryParameters: {
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        print('✓ Loaded messages for room $roomId');
        final payload = response.data;
        final rawMessages = payload is List
            ? payload
            : (payload['results'] as List? ??
                payload['messages'] as List? ??
                const []);

        return rawMessages
            .map(
              (message) => ChatMessage.fromJson(
                Map<String, dynamic>.from(message as Map),
                fallbackRoomId: roomId,
              ),
            )
            .toList();
      } else {
        throw Exception('Failed to fetch messages');
      }
    } on DioException catch (e) {
      print('✗ Get messages error: $e');
      rethrow;
    }
  }

  /// Send a message to a room
  Future<Map<String, dynamic>> sendMessage({
    required int roomId,
    required String content,
    String? mediaUrl,
  }) async {
    try {
      final response = await dio.post(
        '/api/v1/rooms/$roomId/messages/',
        data: {
          'content': content,
          if (mediaUrl != null) 'media_url': mediaUrl,
        },
      );

      if (response.statusCode == 201) {
        print('✓ Message sent to room $roomId');
        return response.data;
      } else {
        throw Exception('Failed to send message');
      }
    } on DioException catch (e) {
      print('✗ Send message error: $e');
      rethrow;
    }
  }

  /// Edit message
  Future<Map<String, dynamic>> editMessage({
    required int messageId,
    required String content,
  }) async {
    try {
      final response = await dio.patch(
        '/api/v1/messages/$messageId/',
        data: {'content': content},
      );

      if (response.statusCode == 200) {
        print('✓ Message edited');
        return response.data;
      } else {
        throw Exception('Failed to edit message');
      }
    } on DioException catch (e) {
      print('✗ Edit message error: $e');
      rethrow;
    }
  }

  /// Delete message
  Future<void> deleteMessage(int messageId) async {
    try {
      final response = await dio.delete('/api/v1/messages/$messageId/');

      if (response.statusCode == 204) {
        print('✓ Message deleted');
      } else {
        throw Exception('Failed to delete message');
      }
    } on DioException catch (e) {
      print('✗ Delete message error: $e');
      rethrow;
    }
  }

  /// React to message
  Future<Map<String, dynamic>> reactToMessage({
    required int messageId,
    required String emoji,
  }) async {
    try {
      final response = await dio.post(
        '/api/v1/messages/$messageId/reactions/',
        data: {'emoji': emoji},
      );

      if (response.statusCode == 201) {
        print('✓ Reaction added to message');
        return response.data;
      } else {
        throw Exception('Failed to add reaction');
      }
    } on DioException catch (e) {
      print('✗ React to message error: $e');
      rethrow;
    }
  }

  // ============== E2EE KEY MANAGEMENT ==============

  /// Upload user's RSA Public Key
  Future<void> uploadPublicKey(String publicKey, String deviceId) async {
    try {
      final response = await dio.post(
        '/api/v1/keys/upload/',
        data: {
          'public_key': publicKey,
          'device_id': deviceId,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✓ Public key uploaded successfully');
      } else {
        throw Exception('Failed to upload public key');
      }
    } on DioException catch (e) {
      print('✗ Upload public key error: $e');
      rethrow;
    }
  }

  /// Get another user's RSA Public Key
  Future<String?> getPublicKey(int userId) async {
    try {
      final response = await dio.get('/api/v1/keys/$userId/');

      if (response.statusCode == 200) {
        return response.data['public_key'];
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        print('⚠ Public key not found for user $userId');
        return null;
      }
      print('✗ Get public key error: $e');
      rethrow;
    }
  }
}

/// Auth Response model
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access'] ?? json['access_token'] ?? '',
      refreshToken: json['refresh'] ?? json['refresh_token'] ?? '',
      user: json['user'] ?? {},
    );
  }
}
