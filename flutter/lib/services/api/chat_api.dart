import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../models/chat_room.dart';
import '../../models/chat_message.dart';
import '../../constants/api_constant.dart';
import '../../utils/failure.dart';
import '../../utils/functional_api_handler.dart';

/// Chat room and message API endpoints
mixin ChatApi on FunctionalApiHandler {
  Dio get dio;

  /// Get or create a direct message room with a friend (lazy creation)
  TaskEither<Failure, ChatRoom> getOrCreateDirectRoom(int friendId) => makeRequest(
        () => dio.post(ApiConstant.getDirectRoom(friendId)),
        (data) => ChatRoom.fromJson(data),
      );

  /// Get all rooms the current user is part of
  TaskEither<Failure, List<ChatRoom>> getRooms() => makeRequest(
        () => dio.get(ApiConstant.rooms),
        (data) {
          final rawRooms = data is List ? data : (data['results'] as List? ?? []);
          return rawRooms.map((room) => ChatRoom.fromJson(room)).toList();
        },
      );

  /// Get specific room details by ID
  TaskEither<Failure, ChatRoom> getRoom(String roomId) => makeRequest(
        () => dio.get(ApiConstant.getRoom(roomId)),
        (data) => ChatRoom.fromJson(data),
      );

  /// Mark all messages in a room as read
  TaskEither<Failure, void> markRoomAsRead(String roomId) => makeRequest(
        () => dio.post(ApiConstant.readRoom(roomId)),
        (_) => null,
      );

  /// Create a new group chat
  TaskEither<Failure, ChatRoom> createGroup({
    required String name,
    String? description,
    required List<int> participantIds,
  }) =>
      makeRequest(
        () => dio.post(
          ApiConstant.createGroup,
          data: {
            'name': name,
            'description': description ?? '',
            'participant_ids': participantIds,
          },
        ),
        (data) => ChatRoom.fromJson(data['room']),
      );

  /// Leave a room (or delete direct chat)
  TaskEither<Failure, void> leaveRoom(String roomId) => makeRequest(
        () => dio.delete(ApiConstant.leaveRoom(roomId)),
        (_) => null,
      );

  /// Add a member to a group chat
  TaskEither<Failure, void> addRoomMember({
    required String roomId,
    required int userId,
  }) =>
      makeRequest(
        () => dio.post(
          ApiConstant.addRoomMember(roomId),
          data: {'user_id': userId},
        ),
        (_) => null,
      );

  /// Get all members in a room
  TaskEither<Failure, Map<String, dynamic>> getRoomMembers(String roomId) =>
      makeRequest(
        () => dio.get(ApiConstant.getRoomMembers(roomId)),
        (data) => Map<String, dynamic>.from(data as Map),
      );

  /// Remove a specific member from a group chat
  TaskEither<Failure, Map<String, dynamic>> removeRoomMember({
    required String roomId,
    required int userId,
  }) =>
      makeRequest(
        () => dio.delete(ApiConstant.removeRoomMember(roomId, userId)),
        (data) => Map<String, dynamic>.from(data as Map),
      );

  /// Get the latest messages in a room
  TaskEither<Failure, List<ChatMessage>> getMessages(
    String roomId, {
    int limit = 20,
  }) =>
      makeRequest(
        () => dio.get(
          ApiConstant.getMessages(roomId),
          queryParameters: {'limit': limit},
        ),
        (data) {
          final rawMessages = data is List
              ? data
              : (data['results'] as List? ??
                  data['messages'] as List? ??
                  const []);
          return rawMessages
              .map(
                (message) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(message as Map),
                  fallbackRoomId: roomId,
                ),
              )
              .toList();
        },
      );

  /// Send a message to a room
  TaskEither<Failure, Map<String, dynamic>> sendMessage({
    required int roomId,
    required String content,
    String? mediaUrl,
  }) =>
      makeRequest(
        () => dio.post(
          ApiConstant.sendMessage(roomId.toString()),
          data: {
            'content': content,
            if (mediaUrl != null) 'media_url': mediaUrl,
          },
        ),
        (data) => data as Map<String, dynamic>,
      );

  /// Edit an existing message
  TaskEither<Failure, Map<String, dynamic>> editMessage({
    required int messageId,
    required String content,
  }) =>
      makeRequest(
        () => dio.patch(
          ApiConstant.editMessage(messageId),
          data: {'content': content},
        ),
        (data) => data as Map<String, dynamic>,
      );

  /// Delete a message
  TaskEither<Failure, void> deleteMessage(int messageId) => makeRequest(
        () => dio.delete(ApiConstant.deleteMessage(messageId)),
        (_) => null,
      );

  /// React to a message with an emoji
  TaskEither<Failure, Map<String, dynamic>> reactToMessage({
    required int messageId,
    required String emoji,
  }) =>
      makeRequest(
        () => dio.post(
          ApiConstant.reactToMessage(messageId),
          data: {'emoji': emoji},
        ),
        (data) => data as Map<String, dynamic>,
      );
}
