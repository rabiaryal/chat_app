/// API Endpoints and Constants
/// Centralized location for all API routes used throughout the application

class ApiConstant {
  // ============== BASE CONFIGURATION ==============
  static const String baseUrl = 'https://chat.rabiaryal.com.np';
  static const String apiVersion = '/api/v1';

  // ============== AUTHENTICATION ENDPOINTS ==============
  static const String register = '$apiVersion/auth/register/';
  static const String login = '$apiVersion/auth/login/';
  static const String logout = '$apiVersion/auth/logout/';
  static const String refreshToken = '$apiVersion/auth/token/refresh/';
  static const String changePassword = '$apiVersion/auth/change-password/';

  // ============== USER ENDPOINTS ==============
  static const String getCurrentUser = '$apiVersion/user/me/';
  static const String deleteUser = '$apiVersion/user/delete/';
  static const String searchUsers = '$apiVersion/user/search/';
  static const String suggestedUsers = '$apiVersion/user/suggested/';

  // ============== FRIEND ENDPOINTS ==============
  static const String friends = '$apiVersion/friends/';
  static String removeFriend(int friendId) => '$apiVersion/friends/$friendId/';
  static const String sendFriendRequest = '$apiVersion/friendship/request/';
  static const String incomingRequests =
      '$apiVersion/friendship/requests/incoming/';
  static const String outgoingRequests =
      '$apiVersion/friendship/requests/outgoing/';
  static const String acceptFriendRequest = '$apiVersion/friendship/accept/';
  static const String rejectFriendRequest = '$apiVersion/friendship/reject/';

  // ============== ROOM ENDPOINTS ==============
  static const String rooms = '$apiVersion/rooms/';
  static String getDirectRoom(int friendId) =>
      '$apiVersion/rooms/direct/$friendId/';
  static const String createGroup = '$apiVersion/rooms/create-group/';
  static String leaveRoom(String roomId) =>
      '$apiVersion/rooms/$roomId/members/';
  static String getRoom(String roomId) => '$apiVersion/rooms/$roomId/';
  static String getRoomMembers(String roomId) =>
      '$apiVersion/rooms/$roomId/members/';
  static String addRoomMember(String roomId) =>
      '$apiVersion/rooms/$roomId/members/';
  static String removeRoomMember(String roomId, int userId) =>
      '$apiVersion/rooms/$roomId/members/$userId/';
  static String readRoom(String roomId) => '$apiVersion/rooms/$roomId/read/';

  // ============== MESSAGE ENDPOINTS ==============
  static String getMessages(String roomId) =>
      '$apiVersion/rooms/$roomId/messages/';
  static String sendMessage(String roomId) =>
      '$apiVersion/rooms/$roomId/messages/';
  static String editMessage(int messageId) =>
      '$apiVersion/messages/$messageId/';
  static String deleteMessage(int messageId) =>
      '$apiVersion/messages/$messageId/';
  static String reactToMessage(int messageId) =>
      '$apiVersion/messages/$messageId/reactions/';

  // ============== E2EE (END-TO-END ENCRYPTION) ENDPOINTS ==============
  static const String uploadPublicKey = '$apiVersion/keys/upload/';
  static String getPublicKey(int userId) => '$apiVersion/keys/$userId/';

  // ============== PUSH NOTIFICATION ENDPOINTS ==============
  static const String registerDevice = '$apiVersion/devices/register/';
  static const String unregisterDevice = '$apiVersion/devices/unregister/';

  // ============== CHAT INITIALIZATION (Legacy) ==============
  static const String chatInitialize = '$apiVersion/chat/initialize/';
  static String getOrCreateRoom(int targetUserId) =>
      '$apiVersion/room/?target_user_id=$targetUserId';

  // ============== QUERY PARAMETERS ==============
  static const String paramPage = 'page';
  static const String paramLimit = 'limit';
  static const String paramSearch = 'search';

  // ============== HTTP METHODS ==============
  static const String methodGet = 'GET';
  static const String methodPost = 'POST';
  static const String methodPatch = 'PATCH';
  static const String methodDelete = 'DELETE';

  // ============== HTTP STATUS CODES ==============
  static const int statusOK = 200;
  static const int statusCreated = 201;
  static const int statusNoContent = 204;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusInternalServerError = 500;

  // ============== TIMEOUT CONFIGURATIONS ==============
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // ============== DEFAULT PAGINATION ==============
  static const int defaultPage = 1;
  static const int defaultLimit = 10;
  static const int defaultMessageLimit = 20;
  static const int defaultSuggestedUsersLimit = 5;

  // ============== DEVICE TYPES FOR FCM ==============
  static const String deviceTypeAndroid = 'android';
  static const String deviceTypeIOS = 'ios';
  static const String deviceTypeWeb = 'web';

  // ============== ERROR MESSAGES ==============
  static const String errorNoToken = 'No access token available';
  static const String errorSessionExpired =
      'Session expired - please login again';
  static const String errorUnauthorized =
      'Unauthorized - tokens may have expired';
  static const String errorNotFound = 'Resource not found';
  static const String errorServerError = 'Server error occurred';
}

/// Query parameter builder helper
class QueryParams {
  static Map<String, dynamic> pagination({
    int page = ApiConstant.defaultPage,
    int limit = ApiConstant.defaultLimit,
  }) {
    return {
      ApiConstant.paramPage: page,
      ApiConstant.paramLimit: limit,
    };
  }

  static Map<String, dynamic> search(String query) {
    return {ApiConstant.paramSearch: query};
  }

  static Map<String, dynamic> searchWithPagination(
    String query, {
    int page = ApiConstant.defaultPage,
    int limit = ApiConstant.defaultLimit,
  }) {
    return {
      ...search(query),
      ...pagination(page: page, limit: limit),
    };
  }
}
