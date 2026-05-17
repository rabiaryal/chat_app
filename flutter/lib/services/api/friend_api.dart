import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../features/auth/models/user.dart';
import '../../models/friend.dart';
import '../../constants/api_constant.dart';
import '../../utils/failure.dart';
import '../../utils/functional_api_handler.dart';
import '../storage/hive_token_storage.dart';

/// Friend-related API endpoints
mixin FriendApi on FunctionalApiHandler {
  Dio get dio;
  HiveTokenStorage get tokenStorage;

  /// Get list of friends (paginated)
  TaskEither<Failure, List<User>> getFriends({int page = 1, int limit = 10}) {
    if (tokenStorage.getAccessToken() == null) {
      return TaskEither.left(const AuthFailure('Authentication required'));
    }
    return makeRequest(
      () => dio.get(
        ApiConstant.friends,
        queryParameters: {'page': page, 'limit': limit},
      ),
      (data) {
        final rawFriends = data is List ? data : (data['results'] as List? ?? []);
        return rawFriends.map((friend) => User.fromJson(friend)).toList();
      },
    );
  }

  /// Get all available users
  TaskEither<Failure, List<User>> getAllUsers() {
    if (tokenStorage.getAccessToken() == null) {
      return TaskEither.left(const AuthFailure('Authentication required'));
    }
    return makeRequest(
      () => dio.get(
        ApiConstant.searchUsers,
        queryParameters: {'search': ''},
      ),
      (data) {
        final results = data is List ? data : (data['results'] as List? ?? []);
        return results.map((user) => User.fromJson(user)).toList();
      },
    );
  }

  /// Send friend request
  TaskEither<Failure, void> sendFriendRequest({required int targetUserId}) =>
      makeRequest(
        () => dio.post(
          ApiConstant.sendFriendRequest,
          data: {'target_user_id': targetUserId},
        ),
        (_) => null,
      );

  /// Get incoming friend requests
  TaskEither<Failure, List<FriendRequest>> getIncomingFriendRequests() =>
      makeRequest(
        () => dio.get(ApiConstant.incomingRequests),
        (data) => (data as List).map((req) => FriendRequest.fromJson(req)).toList(),
      );

  /// Get outgoing friend requests
  TaskEither<Failure, List<FriendRequest>> getOutgoingFriendRequests() =>
      makeRequest(
        () => dio.get(ApiConstant.outgoingRequests),
        (data) => (data as List).map((req) => FriendRequest.fromJson(req)).toList(),
      );

  /// Accept friend request
  TaskEither<Failure, void> acceptFriendRequest(int requestId) => makeRequest(
        () => dio.post(
          ApiConstant.acceptFriendRequest,
          data: {'friendship_id': requestId},
        ),
        (_) => null,
      );

  /// Reject friend request
  TaskEither<Failure, void> rejectFriendRequest(int requestId) => makeRequest(
        () => dio.post(
          ApiConstant.rejectFriendRequest,
          data: {'friendship_id': requestId},
        ),
        (_) => null,
      );

  /// Remove friend
  TaskEither<Failure, void> removeFriend(int friendId) => makeRequest(
        () => dio.delete(ApiConstant.removeFriend(friendId)),
        (_) => null,
      );

  /// Get suggested users (non-friends, for discovery)
  TaskEither<Failure, List<User>> getSuggestedUsers({int page = 1, int limit = 5}) {
    if (tokenStorage.getAccessToken() == null) {
      return TaskEither.left(const AuthFailure('Authentication required'));
    }
    return makeRequest(
      () => dio.get(
        ApiConstant.suggestedUsers,
        queryParameters: {'page': page, 'limit': limit},
      ),
      (data) {
        final results = data is List ? data : (data['results'] as List? ?? []);
        return results.map((user) => User.fromJson(user)).toList();
      },
    );
  }

  /// Search for users by query string
  TaskEither<Failure, List<User>> searchUsers(String query) {
    if (tokenStorage.getAccessToken() == null) {
      return TaskEither.left(const AuthFailure('Authentication required'));
    }
    return makeRequest(
      () => dio.get(
        ApiConstant.searchUsers,
        queryParameters: {'search': query},
      ),
      (data) {
        final results = data is List ? data : (data['results'] as List? ?? []);
        return results.map((user) => User.fromJson(user)).toList();
      },
    );
  }
}
