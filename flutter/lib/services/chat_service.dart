/// Enhanced Chat Service with JWT persistence and streaming support
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import '../models/chat_message.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChatService {
  final ApiService apiService;
  final EncryptionService encryptionService;
  final String wsBaseUrl;

  WebSocketChannel? _webSocketChannel;
  StreamController<ChatMessage>? _messageStreamController;
  StreamController<bool>? _connectionStreamController;
  Timer? _reconnectionTimer;
  Timer? _typingDebounceTimer;
  bool _isConnected = false;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;
  String? _currentRoomId;
  // Connectivity
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;

  ChatService({
    required this.apiService,
    EncryptionService? encryptionService,
    this.wsBaseUrl = 'ws://192.168.1.65:8000',
  }) : encryptionService = encryptionService ?? EncryptionService() {
    _messageStreamController = StreamController<ChatMessage>.broadcast();
    _connectionStreamController = StreamController<bool>.broadcast();
    _initConnectivityListener();
  }

  void _initConnectivityListener() async {
    try {
      final status = await _connectivity.checkConnectivity();
      _isOnline = status != ConnectivityResult.none;
    } catch (e) {
      _isOnline = true;
    }

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) async {
      final nowOnline = result != ConnectivityResult.none;
      if (_isOnline == nowOnline) return;
      _isOnline = nowOnline;
      print('🔌 Connectivity changed: ${_isOnline ? 'online' : 'offline'}');

      if (!_isOnline) {
        // When going offline, cancel reconnection attempts and mark disconnected
        _reconnectionTimer?.cancel();
        _reconnectionTimer = null;
        _connectionStreamController?.add(false);
        _messageStreamController?.addError('Offline - connection paused');
      } else {
        // When back online, attempt to reconnect immediately if we have a room
        if (_currentRoomId != null && !_isConnected) {
          try {
            await connectWebSocket(roomId: _currentRoomId!);
          } catch (_) {
            // connectWebSocket will schedule reconnection if needed
          }
        }
      }
    });
  }

  // Streams
  Stream<ChatMessage> get messageStream =>
      _messageStreamController?.stream ?? Stream.empty();
  Stream<bool> get connectionStream =>
      _connectionStreamController?.stream ?? Stream.empty();

  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;

  /// Restore session from TokenManager
  Future<bool> restoreSession() async {
    try {
      return await apiService.restoreSession();
    } catch (e) {
      print('✗ Session restore error: $e');
      return false;
    }
  }

  /// Login and save tokens via ApiService
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final authResponse = await apiService.login(
        username: username,
        password: password,
      );
      return {
        'user': authResponse.user,
        'access': authResponse.accessToken,
        'refresh': authResponse.refreshToken,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Register and auto-login
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      await apiService.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      // Auto-login after registration
      return await login(username: username, password: password);
    } catch (e) {
      rethrow;
    }
  }

  /// Connect to WebSocket with JWT authentication
  Future<void> connectWebSocket({
    required String roomId,
    String? token,
  }) async {
    // If already connected to this room, do nothing
    if (_isConnected && _currentRoomId == roomId && _webSocketChannel != null) {
      print('ℹ WebSocket already connected to room: $roomId');
      return;
    }

    try {
      // Disconnect existing connection if any to prevent duplicate listeners
      await disconnectWebSocket();

      // Get token from TokenManager if not provided
      var accessToken = token ?? apiService.tokenManager.accessToken;

      // If no token available, try to restore session first
      if (accessToken == null) {
        print('⚠ No token available, attempting to restore session...');
        final sessionRestored = await apiService.restoreSession();
        if (!sessionRestored) {
          throw Exception(
              'No authentication token available - please login first');
        }
        accessToken = apiService.tokenManager.accessToken;
      }

      if (accessToken == null) {
        throw Exception('Failed to retrieve authentication token');
      }

      _currentRoomId = roomId;

      // Construct websocket URI reliably from wsBaseUrl (supports http/https/ws/wss)
      final baseUri = Uri.parse(wsBaseUrl);
      String scheme;
      if (baseUri.scheme == 'http') {
        scheme = 'ws';
      } else if (baseUri.scheme == 'https') {
        scheme = 'wss';
      } else if (baseUri.scheme == 'ws' || baseUri.scheme == 'wss') {
        scheme = baseUri.scheme;
      } else {
        // Fallback to ws
        scheme = 'ws';
      }

      final wsUri = Uri(
        scheme: scheme,
        host: baseUri.host,
        port: baseUri.hasPort ? baseUri.port : null,
        path: '/ws/chat/$roomId/',
        queryParameters: {'token': accessToken},
      );
      print(
          '🔌 Connecting to WebSocket: ${wsUri.toString().replaceAll(RegExp(r'token=.*'), 'token=***')}');

      _webSocketChannel = WebSocketChannel.connect(wsUri);

      // Listen to incoming messages
      _webSocketChannel!.stream.listen(
        (dynamic message) => _handleWebSocketMessage(message as String, roomId),
        onError: (error) => _handleWebSocketError(error, roomId),
        onDone: () => _handleWebSocketDone(roomId),
      );

      _isConnected = true;
      _reconnectionAttempts = 0;
      _connectionStreamController?.add(true);
      print('✓ WebSocket connected to room: $roomId');
    } catch (e) {
      print('✗ WebSocket connection error: $e');
      _isConnected = false;
      _connectionStreamController?.add(false);
      // Only schedule reconnection when device is online
      if (_isOnline) {
        await _scheduleReconnection(roomId, token);
      } else {
        print('⚠ Offline - not scheduling reconnection');
      }
      rethrow;
    }
  }

  /// Send text message with proper schema validation
  void sendTextMessage({
    required String content,
    required String roomId,
    required int userId,
    required String username,
  }) {
    if (!_isConnected) {
      _messageStreamController?.addError('WebSocket not connected');
      return;
    }

    if (content.trim().isEmpty) {
      _messageStreamController?.addError('Message cannot be empty');
      return;
    }

    if (content.length > 5000) {
      _messageStreamController?.addError('Message exceeds 5000 characters');
      return;
    }

    // Send via WebSocket with proper schema
    try {
      final message = {
        'type': 'text_message',
        'text': content.trim(),
        'room_id': roomId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      print(
          '📤 Sending message: ${content.substring(0, min(50, content.length))}...');
      _webSocketChannel?.sink.add(jsonEncode(message));
    } catch (e) {
      _messageStreamController?.addError('Failed to send message: $e');
      print('✗ Send message error: $e');
    }
  }

  /// Send secure (E2EE) message
  Future<void> sendSecureMessage({
    required String content,
    required String roomId,
    required int recipientId,
  }) async {
    if (!_isConnected) {
      _messageStreamController?.addError('WebSocket not connected');
      return;
    }

    try {
      // 1. Fetch recipient's public key
      final recipientPublicKey = await apiService.getPublicKey(recipientId);
      if (recipientPublicKey == null) {
        throw Exception('Recipient does not have a public key for E2EE');
      }

      // 2. Encrypt locally
      final encryptedData =
          await encryptionService.encryptMessage(content, recipientPublicKey);

      // 3. Send via WebSocket
      final message = {
        'type': 'secure_message',
        'recipient_id': recipientId,
        'encrypted_payload': encryptedData['encrypted_payload'],
        'encrypted_key': encryptedData['encrypted_key'],
        'iv': encryptedData['iv'],
        'room_id': roomId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('🔐 Sending secure message...');
      _webSocketChannel?.sink.add(jsonEncode(message));
    } catch (e) {
      _messageStreamController?.addError('Failed to send secure message: $e');
      print('✗ Secure message error: $e');
    }
  }

  /// Request AI response
  void requestAIResponse({
    required String content,
    required String roomId,
    required int userId,
    required String username,
  }) {
    if (!_isConnected) {
      _messageStreamController?.addError('WebSocket not connected');
      return;
    }

    if (content.trim().isEmpty) {
      _messageStreamController?.addError('AI request cannot be empty');
      return;
    }

    // Request AI response with proper schema
    try {
      final message = {
        'type': 'ai_request',
        'text': content.trim(),
        'room_id': roomId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      print('🤖 Requesting AI response...');
      _webSocketChannel?.sink.add(jsonEncode(message));
    } catch (e) {
      _messageStreamController?.addError('Failed to request AI response: $e');
      print('✗ AI request error: $e');
    }
  }

  /// Send typing indicator with debouncing
  void sendTypingIndicator(String roomId) {
    if (!_isConnected) return;

    // Cancel previous debounce timer
    _typingDebounceTimer?.cancel();

    // Send typing indicator
    try {
      final message = {
        'type': 'typing',
        'room_id': roomId,
        'text': '',
      };
      _webSocketChannel?.sink.add(jsonEncode(message));
    } catch (e) {
      print('⚠ Typing indicator error: $e');
    }

    // Send stop_typing after 2 seconds of inactivity
    _typingDebounceTimer = Timer(Duration(seconds: 2), () {
      try {
        final message = {
          'type': 'stop_typing',
          'room_id': roomId,
          'text': '',
        };
        _webSocketChannel?.sink.add(jsonEncode(message));
      } catch (e) {
        // Silently fail for stop typing
      }
    });
  }

  /// Mark a message as read
  void sendMarkRead(String roomId, String messageId) {
    if (!_isConnected) return;
    try {
      final message = {
        'type': 'mark_read',
        'room_id': roomId,
        'message_id': messageId,
      };
      _webSocketChannel?.sink.add(jsonEncode(message));
    } catch (e) {
      print('⚠ Mark read error: $e');
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(String messageText, String roomId) {
    try {
      final json = jsonDecode(messageText) as Map<String, dynamic>;
      final messageType = json['type'] as String?;

      print('📨 Received: $messageType');

      switch (messageType) {
        case 'text_message':
          final message = ChatMessage.fromWebSocketMessage(json, roomId);
          _messageStreamController?.add(message);
          break;

        case 'secure_message':
          // 1. Parse as secure message
          final message = ChatMessage.fromWebSocketMessage(json, roomId);

          // 2. Decrypt if it's for us (or if we are the sender and want to see it)
          _decryptAndEmitMessage(message);
          break;

        case 'ai_response':
          final aiMessage = ChatMessage(
            id: json['message_id'] ?? '',
            content: json['text'] ?? '',
            userId: json['user_id'] ?? 0,
            username: 'AI Assistant',
            roomId: roomId,
            type: MessageType.ai,
            status: MessageStatus.delivered,
            isBot: true,
            timestamp: DateTime.parse(
                json['timestamp'] ?? DateTime.now().toIso8601String()),
          );
          _messageStreamController?.add(aiMessage);
          break;

        case 'typing':
          // Handle user typing indicator
          print('${json['username']} is typing...');
          break;

        case 'stop_typing':
          // User stopped typing
          break;

        case 'message_read':
          final readMessage = ChatMessage(
            id: json['message_id'] ?? '',
            content: '',
            userId: json['user_id'] ?? 0,
            username: '',
            roomId: roomId,
            status: MessageStatus.read,
            timestamp: DateTime.now(),
          );
          _messageStreamController?.add(readMessage);
          break;

        case 'user_joined':
          print('${json['username']} joined the room');
          break;

        case 'user_left':
          print('${json['username']} left the room');
          break;

        case 'room_users':
          print('Room has ${json['users_count']} users');
          break;

        case 'error':
          final errorMsg = json['message'] as String? ?? 'Server error';
          print('✗ Server error: $errorMsg');
          _messageStreamController?.addError(errorMsg);
          break;

        default:
          print('⚠ Unknown message type: $messageType');
          break;
      }
    } catch (e) {
      print('✗ Parse message error: $e');
      _messageStreamController?.addError('Failed to parse message: $e');
    }
  }

  /// Decrypt a secure message and emit it to the stream
  Future<void> _decryptAndEmitMessage(ChatMessage message) async {
    try {
      if (message.encryptedPayload == null ||
          message.encryptedKey == null ||
          message.iv == null) {
        _messageStreamController?.add(message.copyWith(
          content: '[Error: Incomplete secure message]',
        ));
        return;
      }

      final decryptedContent = await encryptionService.decryptMessage(
        encryptedPayload: message.encryptedPayload!,
        encryptedKey: message.encryptedKey!,
        ivBase64: message.iv!,
      );

      _messageStreamController?.add(message.copyWith(
        content: decryptedContent,
      ));
    } catch (e) {
      print('✗ Decryption error: $e');
      _messageStreamController?.add(message.copyWith(
        content: '[Error: Could not decrypt message]',
      ));
    }
  }

  /// Handle WebSocket errors
  void _handleWebSocketError(dynamic error, String roomId) {
    print('✗ WebSocket error: $error');
    _isConnected = false;
    _connectionStreamController?.add(false);
    _messageStreamController?.addError('WebSocket error: $error');
    if (_currentRoomId == roomId) {
      _scheduleReconnection(roomId, null);
    }
  }

  /// Handle WebSocket disconnection
  void _handleWebSocketDone(String roomId) {
    print('⚠ WebSocket disconnected');
    _isConnected = false;
    _connectionStreamController?.add(false);
    if (_currentRoomId == roomId) {
      _scheduleReconnection(roomId, null);
    }
  }

  /// Schedule automatic reconnection with exponential backoff
  Future<void> _scheduleReconnection(String roomId, String? token) async {
    // Do not attempt reconnect if offline
    if (!_isOnline) {
      print('⚠ Device offline — skipping reconnection schedule');
      return;
    }

    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      _messageStreamController?.addError(
        'Failed to reconnect after $_maxReconnectionAttempts attempts',
      );
      print('✗ Max reconnection attempts reached');
      return;
    }

    _reconnectionAttempts++;

    // Exponential backoff: 2s, 4s, 8s, 16s, 32s
    final backoffMs = 2000 * _exponent(_reconnectionAttempts);
    final backoffDuration = Duration(milliseconds: backoffMs);

    print(
        '⏱ Reconnection attempt $_reconnectionAttempts/$_maxReconnectionAttempts '
        'in ${backoffDuration.inSeconds}s...');

    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(backoffDuration, () async {
      try {
        await connectWebSocket(roomId: roomId, token: token);
      } catch (e) {
        // Recursively retry
        await _scheduleReconnection(roomId, token);
      }
    });
  }

  /// Calculate exponential backoff value (2^n)
  int _exponent(int n) => 1 << n; // 2^n

  /// Disconnect WebSocket
  Future<void> disconnectWebSocket() async {
    _reconnectionTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _reconnectionAttempts = 0;
    _isConnected = false;
    _currentRoomId = null;

    try {
      await _webSocketChannel?.sink.close();
    } catch (e) {
      print('⚠ Error closing WebSocket: $e');
    }

    _webSocketChannel = null;
    _connectionStreamController?.add(false);
    print('✓ WebSocket disconnected');
  }

  // (connectivity cancellation merged into final dispose below)

  /// Setup E2EE: Generate keys if needed and upload public key
  Future<void> setupE2EE() async {
    try {
      String? publicKey = await encryptionService.getLocalPublicKey();

      if (publicKey == null) {
        print('🔑 Generating new RSA Key Pair for E2EE...');
        final keys = await encryptionService.generateKeyPair();
        publicKey = keys['publicKey'];
      } else {
        print('🔑 Local E2EE keys already exist');
      }

      if (publicKey != null) {
        // Upload to server (deviceId could be any unique identifier or empty for now)
        await apiService.uploadPublicKey(publicKey, 'mobile-device-1');
        print('✓ E2EE Public Key verified on server');
      }
    } catch (e) {
      print('✗ E2EE Setup error: $e');
      // We don't throw here to avoid blocking app start, but E2EE won't work
    }
  }

  /// Logout
  Future<void> logout() async {
    await disconnectWebSocket();
    await apiService.logout();
    print('✓ User logged out');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _connectivitySubscription?.cancel();
    _reconnectionTimer?.cancel();
    _typingDebounceTimer?.cancel();
    await _messageStreamController?.close();
    await _connectionStreamController?.close();
    await disconnectWebSocket();
    print('✓ ChatService disposed');
  }
}
