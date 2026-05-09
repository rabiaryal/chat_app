import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'hive_token_storage.dart';

/// ChatRepository: Combines REST API and WebSocket for complete chat functionality
///
/// ARCHITECTURE:
/// 1. **Persistent Layer** (Django): `GET /api/room/?target_user_id=X`
///    → Returns existing room or creates new one
///
/// 2. **WebSocket Layer** (Django Channels): `ws://django:8000/ws/chat/{room_id}/`
///    → Handles real-time messaging
///
/// 3. **Lazy Room Creation**: Room is only created when user initiates chat
///
/// SEQUENCE:
/// 1. User clicks "Chat with @alice"
/// 2. Flutter calls: `getOrCreateRoom(target_user_id: 5)`
/// 3. Django checks database:
///    - Room exists? → Return room_id
///    - New room? → Create and return room_id
/// 4. Flutter connects: `connectToRoom(room_id)`
/// 5. Django validates:
///    - JWT token valid? ✓
///    - User is room member? ✓
///    - Accept connection
class ChatRepository {
  final ApiService apiService;
  final HiveTokenStorage tokenStorage;

  // Active WebSocket connections per room
  final Map<String, WebSocketChannel> _socketConnections = {};

  // Stream controllers for receiving messages
  final Map<String, StreamController<dynamic>> _messageStreamControllers = {};

  ChatRepository({
    required this.apiService,
    HiveTokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? HiveTokenStorage();

  /// Get or create a room with another user
  ///
  /// Flow:
  /// 1. Query Django: "Does room exist with user {target_user_id}?"
  /// 2. Django checks ChatRoom.participants M2M in database
  /// 3. Returns existing room_id or creates new one
  /// 4. Flutter receives room_id
  /// 5. Next step: User connects WebSocket to Django Channels
  ///
  /// Returns: room_id (string UUID)
  Future<String?> getOrCreateRoom({required int targetUserId}) async {
    try {
      debugPrint('🔍 Checking for room with user $targetUserId...');

      final response = await http.get(
        Uri.parse(
            '${apiService.baseUrl}/api/v1/room/?target_user_id=$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${tokenStorage.getAccessToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final roomId = data['room_id'];
        final created = data['created'] == true;
        final roomName = data['room_name'];

        if (created) {
          debugPrint('✓ New room created: $roomId ($roomName)');
        } else {
          debugPrint('✓ Room exists: $roomId ($roomName)');
        }

        return roomId;
      } else {
        debugPrint('✗ Failed to get/create room: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('✗ Error in getOrCreateRoom: $e');
      return null;
    }
  }

  /// Connect to a room via WebSocket
  ///
  /// Prerequisites:
  /// 1. Room ID must exist (from getOrCreateRoom)
  /// 2. Access token must be valid
  ///
  /// Django Verification:
  /// 1. Check JWT token ✓
  /// 2. Check if user is room member ✓ (DATABASE IS TRUTH)
  /// 3. Accept connection
  ///
  /// Returns: Stream<dynamic> of messages
  Stream<dynamic> connectToRoom({required String roomId}) {
    if (_socketConnections.containsKey(roomId)) {
      debugPrint('⚠ Already connected to room $roomId');
      return _messageStreamControllers[roomId]!.stream;
    }

    try {
      final token = tokenStorage.getAccessToken();
      if (token == null) {
        debugPrint('✗ No access token available');
        throw Exception('Not authenticated');
      }

      // Construct WebSocket URL robustly from API base (supports http/https)
      final baseUri = Uri.parse(apiService.baseUrl);
      final wsScheme = (baseUri.scheme == 'https') ? 'wss' : 'ws';
      final wsUri = Uri(
        scheme: wsScheme,
        host: baseUri.host,
        port: baseUri.hasPort ? baseUri.port : null,
        path: '/ws/chat/$roomId/',
        queryParameters: {'token': token},
      );
      debugPrint(
          '🔗 Connecting to WebSocket: ${wsUri.toString().replaceAll(RegExp(r'token=.*'), 'token=***')}');

      // Create WebSocket connection
      final channel = WebSocketChannel.connect(wsUri);

      // Create message stream controller
      final streamController = StreamController<dynamic>.broadcast(
        onCancel: () {
          debugPrint('⚠ Stream cancelled for room $roomId');
          _socketConnections.remove(roomId);
          _messageStreamControllers.remove(roomId);
        },
      );

      _socketConnections[roomId] = channel;
      _messageStreamControllers[roomId] = streamController;

      // Listen for incoming messages
      channel.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            streamController.add(data);
            debugPrint('📨 Message in $roomId: ${data['type']}');
          } catch (e) {
            debugPrint('✗ Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('✗ WebSocket error in $roomId: $error');
          streamController.addError(error);
        },
        onDone: () {
          debugPrint('✗ WebSocket disconnected from $roomId');
          _socketConnections.remove(roomId);
          streamController.close();
          _messageStreamControllers.remove(roomId);
        },
      );

      debugPrint('✓ Connected to room $roomId');
      return streamController.stream;
    } catch (e) {
      debugPrint('✗ Error connecting to room $roomId: $e');
      rethrow;
    }
  }

  /// Send a message to the room
  ///
  /// Message is sent via WebSocket and persisted by Django to database
  ///
  /// Args:
  ///   - roomId: The room to send to
  ///   - content: Message text
  ///   - type: Message type (default: 'text_message')
  void sendMessage({
    required String roomId,
    required String content,
    String type = 'text_message',
  }) {
    try {
      if (!_socketConnections.containsKey(roomId)) {
        debugPrint('✗ Not connected to room $roomId');
        return;
      }

      final message = {
        'type': type,
        'text': content,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _socketConnections[roomId]!.sink.add(json.encode(message));
      debugPrint('✓ Message sent to $roomId: ${content.substring(0, 50)}...');
    } catch (e) {
      debugPrint('✗ Error sending message: $e');
    }
  }

  /// Send AI request to room
  ///
  /// Django will:
  /// 1. Validate message
  /// 2. Generate AI response using OpenAI
  /// 3. Broadcast to all room members
  /// 4. Persist both prompt and response
  void sendAIRequest({
    required String roomId,
    required String prompt,
  }) {
    sendMessage(
      roomId: roomId,
      content: prompt,
      type: 'ai_request',
    );
  }

  /// Send typing indicator
  ///
  /// Shows other users that you're typing (optional, nice-to-have)
  void sendTypingIndicator({required String roomId}) {
    sendMessage(
      roomId: roomId,
      content: '',
      type: 'typing',
    );
  }

  /// Stop typing indicator
  void sendStopTyping({required String roomId}) {
    sendMessage(
      roomId: roomId,
      content: '',
      type: 'stop_typing',
    );
  }

  /// Disconnect from a room
  ///
  /// Closes WebSocket and cleans up resources
  Future<void> disconnectFromRoom({required String roomId}) async {
    try {
      if (_socketConnections.containsKey(roomId)) {
        await _socketConnections[roomId]!.sink.close(status.goingAway);
        _socketConnections.remove(roomId);
        debugPrint('✓ Disconnected from room $roomId');
      }

      if (_messageStreamControllers.containsKey(roomId)) {
        await _messageStreamControllers[roomId]!.close();
        _messageStreamControllers.remove(roomId);
      }
    } catch (e) {
      debugPrint('✗ Error disconnecting: $e');
    }
  }

  /// Disconnect from all rooms
  Future<void> disconnectAll() async {
    final rooms = _socketConnections.keys.toList();
    for (final room in rooms) {
      await disconnectFromRoom(roomId: room);
    }
  }

  /// Check if connected to a room
  bool isConnected({required String roomId}) {
    return _socketConnections.containsKey(roomId);
  }

  /// Get number of active connections
  int get activeConnectionCount => _socketConnections.length;

  /// Cleanup resources (call on app dispose)
  Future<void> dispose() async {
    await disconnectAll();
  }
}
