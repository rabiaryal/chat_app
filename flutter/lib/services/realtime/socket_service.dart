import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/chat_message.dart';
import '../../models/message_model.dart';
import '../api_service.dart';
import '../storage/chat_persistence_service.dart';
import '../storage/hive_token_storage.dart';
import 'encryption_service.dart';

/// Singleton WebSocket service that writes incoming messages to Hive first.
class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService({
    required ApiService apiService,
    HiveTokenStorage? tokenStorage,
    EncryptionService? encryptionService,
    Future<void> Function()? onUnauthorized,
  }) {
    _instance._configure(
      apiService: apiService,
      tokenStorage: tokenStorage ?? HiveTokenStorage(),
      encryptionService: encryptionService ?? EncryptionService(),
      onUnauthorized: onUnauthorized,
    );
    return _instance;
  }

  SocketService._internal();

  static const Duration _reconnectInterval = Duration(seconds: 5);

  late ApiService _apiService;
  late HiveTokenStorage _tokenStorage;
  late EncryptionService _encryptionService;
  late ChatPersistenceService _persistenceService;
  Future<void> Function()? _onUnauthorized;

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final ValueNotifier<bool> connectionState = ValueNotifier<bool>(false);

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  Timer? _reconnectTimer;
  bool _configured = false;
  bool _isConnected = false;
  String? _currentRoomId;
  int _reconnectAttempts = 0;
  final Map<String, Map<String, dynamic>> _outgoingPayloads = {};

  void _configure({
    required ApiService apiService,
    required HiveTokenStorage tokenStorage,
    required EncryptionService encryptionService,
    Future<void> Function()? onUnauthorized,
  }) {
    _apiService = apiService;
    _tokenStorage = tokenStorage;
    _encryptionService = encryptionService;
    _persistenceService = ChatPersistenceService();
    _onUnauthorized = onUnauthorized;
    if (!_configured) {
      _configured = true;
    }
  }

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;

  void setUnauthorizedHandler(Future<void> Function()? handler) {
    _onUnauthorized = handler;
  }

  Future<void> connect({required String roomId}) async {
    if (_isConnected && _currentRoomId == roomId && _channel != null) {
      return;
    }

    await _persistenceService.initialize();

    final token = _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required - please login first');
    }

    await disconnect();
    _currentRoomId = roomId;

    final wsUri = _buildWebSocketUri(roomId, token);
    try {
      _channel = WebSocketChannel.connect(wsUri);
      _socketSubscription = _channel!.stream.listen(
        (dynamic rawMessage) => _handleIncoming(rawMessage, roomId),
        onError: (error) => _handleSocketError(error, roomId),
        onDone: () => _handleSocketDone(roomId),
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _updateConnectionState(true);
      await _flushPendingMessages(roomId);
    } catch (error) {
      _handleSocketError(error, roomId);
      rethrow;
    }
  }

  Future<void> queueOutgoingMessage({
    required ChatMessage message,
    required Map<String, dynamic> payload,
  }) async {
    await _persistenceService.initialize();

    final isPending = !(_isConnected && _currentRoomId == message.roomId);
    final pendingMessage = message.copyWith(status: MessageStatus.sending);
    final roomId = pendingMessage.roomId;
    final model = MessageModel.fromChatMessage(pendingMessage)
        .copyWith(isPending: isPending);
    await _persistenceService.upsertMessage(roomId, model);

    final payloadKey = _payloadKey(roomId, pendingMessage.id);
    _outgoingPayloads[payloadKey] = payload;

    if (_isConnected && _currentRoomId == roomId) {
      _sendRawPayload(payload);
    } else {
      _scheduleReconnect(roomId);
    }
  }

  Future<void> sendTextMessage({required ChatMessage message}) async {
    final payload = {
      'type': 'text_message',
      'text': message.content.trim(),
      'room_id': message.roomId,
      'timestamp': message.timestamp.toIso8601String(),
      'client_message_id': message.id,
    };
    await queueOutgoingMessage(message: message, payload: payload);
  }

  //paylaod is the data send to the backend server and the message is for the local hive sotrage

  Future<void> sendSecureMessage({required ChatMessage message}) async {
    final payload = {
      'type': 'secure_message',
      'recipient_id': message.userId,
      'encrypted_payload': message.encryptedPayload,
      'encrypted_key': message.encryptedKey,
      'iv': message.iv,
      'room_id': message.roomId,
      'timestamp': message.timestamp.toIso8601String(),
      'client_message_id': message.id,
    };
    await queueOutgoingMessage(message: message, payload: payload);
  }

  Future<void> requestAIResponse({required ChatMessage message}) async {
    final payload = {
      'type': 'ai_request',
      'text': message.content.trim(),
      'room_id': message.roomId,
      'timestamp': message.timestamp.toIso8601String(),
      'client_message_id': message.id,
    };
    await queueOutgoingMessage(message: message, payload: payload);
  }

  void sendTypingIndicator(String roomId) {
    if (!_isConnected || _currentRoomId != roomId) {
      return;
    }

    _sendRawPayload({'type': 'typing', 'room_id': roomId, 'text': ''});
  }

  void sendMarkRead(String roomId, String messageId) {
    if (!_isConnected || _currentRoomId != roomId) {
      return;
    }

    _sendRawPayload({
      'type': 'mark_read',
      'room_id': roomId,
      'message_id': messageId,
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _isConnected = false;
    _updateConnectionState(false);

    try {
      await _socketSubscription?.cancel();
    } catch (_) {}
    _socketSubscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _currentRoomId = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
    connectionState.dispose();
  }

  Uri _buildWebSocketUri(String roomId, String token) {
    final baseUri = Uri.parse(_apiService.baseUrl);
    final scheme = baseUri.scheme == 'https'
        ? 'wss'
        : baseUri.scheme == 'http'
            ? 'ws'
            : baseUri.scheme;

    return Uri(
      scheme: scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/ws/chat/$roomId/',
      queryParameters: {'token': token},
    );
  }

  Future<void> _handleIncoming(dynamic rawMessage, String roomId) async {
    try {
      final messageText =
          rawMessage is String ? rawMessage : rawMessage.toString();
      final data = jsonDecode(messageText) as Map<String, dynamic>;
      final type = data['type']?.toString();

      if (type == 'error' && _looksUnauthorized(data['message']?.toString())) {
        await _handleUnauthorized(
            data['message']?.toString() ?? 'Unauthorized');
        return;
      }

      switch (type) {
        case 'text_message':
          await _persistIncomingMessage(
            ChatMessage.fromWebSocketMessage(data, roomId),
          );
          break;
        case 'secure_message':
          await _handleSecureIncoming(data, roomId);
          break;
        case 'ai_response':
          await _persistIncomingMessage(
            ChatMessage(
              id: data['message_id']?.toString() ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              content: data['text']?.toString() ?? '',
              userId: data['user_id'] is int
                  ? data['user_id'] as int
                  : int.tryParse(data['user_id']?.toString() ?? '') ?? 0,
              username: 'AI Assistant',
              roomId: roomId,
              type: MessageType.ai,
              status: MessageStatus.delivered,
              isBot: true,
              timestamp: DateTime.parse(
                data['timestamp']?.toString() ??
                    DateTime.now().toIso8601String(),
              ),
            ),
          );
          break;
        case 'message_read':
          await _persistenceService.markMessageAsRead(
            roomId,
            data['message_id']?.toString() ?? '',
          );
          _messageController.add(
            ChatMessage(
              id: data['message_id']?.toString() ?? '',
              content: '',
              userId: data['user_id'] is int
                  ? data['user_id'] as int
                  : int.tryParse(data['user_id']?.toString() ?? '') ?? 0,
              username: '',
              roomId: roomId,
              status: MessageStatus.read,
              timestamp: DateTime.now(),
            ),
          );
          break;
        case 'typing':
        case 'stop_typing':
        case 'user_joined':
        case 'user_left':
        case 'room_users':
          break;
        case 'error':
          if (_looksUnauthorized(data['message']?.toString())) {
            await _handleUnauthorized(
                data['message']?.toString() ?? 'Unauthorized');
          } else {
            _messageController
                .addError(data['message']?.toString() ?? 'Server error');
          }
          break;
        default:
          break;
      }
    } catch (error) {
      _messageController.addError('Failed to parse message: $error');
    }
  }

  Future<void> _handleSecureIncoming(
    Map<String, dynamic> data,
    String roomId,
  ) async {
    final incoming = ChatMessage.fromWebSocketMessage(data, roomId);
    if (incoming.encryptedPayload == null ||
        incoming.encryptedKey == null ||
        incoming.iv == null) {
      await _persistIncomingMessage(
        incoming.copyWith(content: '[Error: Incomplete secure message]'),
      );
      return;
    }

    try {
      final decryptedContent = await _encryptionService.decryptMessage(
        encryptedPayload: incoming.encryptedPayload!,
        encryptedKey: incoming.encryptedKey!,
        ivBase64: incoming.iv!,
      );
      await _persistIncomingMessage(
          incoming.copyWith(content: decryptedContent));
    } catch (error) {
      await _persistIncomingMessage(
        incoming.copyWith(content: '[Error: Could not decrypt message]'),
      );
    }
  }

  Future<void> _persistIncomingMessage(ChatMessage message) async {
    await _persistenceService.initialize();

    final match = await _persistenceService.findMatchingMessage(
      roomId: message.roomId,
      userId: message.userId,
      text: message.content,
    );

    if (match != null && match.id != message.id) {
      _outgoingPayloads.remove(_payloadKey(message.roomId, match.id));
      await _persistenceService.updateMessageId(
        message.roomId,
        match.id,
        MessageModel.fromChatMessage(
          message.copyWith(
            id: message.id,
            status: MessageStatus.delivered,
          ),
        ),
      );
    } else {
      await _persistenceService.upsertMessage(
        message.roomId,
        MessageModel.fromChatMessage(
          message.copyWith(status: MessageStatus.delivered),
        ),
      );
    }

    _messageController.add(message.copyWith(status: MessageStatus.delivered));
  }

  void _handleSocketError(dynamic error, String roomId) {
    _isConnected = false;
    _updateConnectionState(false);

    if (_looksUnauthorized(error.toString())) {
      unawaited(_handleUnauthorized(error.toString()));
      return;
    }

    _messageController.addError('WebSocket error: $error');
    if (_currentRoomId == roomId) {
      _scheduleReconnect(roomId);
    }
  }

  void _handleSocketDone(String roomId) {
    _isConnected = false;
    _updateConnectionState(false);
    if (_currentRoomId == roomId) {
      _scheduleReconnect(roomId);
    }
  }

  void _scheduleReconnect(String roomId) {
    if (_reconnectTimer?.isActive == true) {
      return;
    }

    _reconnectAttempts++;
    _reconnectTimer = Timer(_reconnectInterval, () async {
      try {
        await connect(roomId: roomId);
      } catch (_) {
        if (_reconnectAttempts < 12) {
          _scheduleReconnect(roomId);
        }
      }
    });
  }

  Future<void> _flushPendingMessages(String roomId) async {
    await _persistenceService.initialize();
    final box = Hive.box<Map>('chat_box');
    final pendingMessages = box.values
        .map((value) => MessageModel.fromJson(Map<String, dynamic>.from(value)))
        .where((message) => message.roomId == roomId && message.isPending)
        .toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

    for (final message in pendingMessages) {
      final payload = _outgoingPayloads[_payloadKey(roomId, message.id)] ??
          _buildPayloadFromMessage(message);
      _sendRawPayload(payload);
    }
  }

  Map<String, dynamic> _buildPayloadFromMessage(MessageModel message) {
    return {
      'type': 'text_message',
      'text': message.text,
      'room_id': message.roomId,
      'timestamp': message.timestamp.toIso8601String(),
      'client_message_id': message.id,
    };
  }

  void _sendRawPayload(Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null) {
      return;
    }

    _channel!.sink.add(jsonEncode(payload));
  }

  Future<void> _handleUnauthorized(String reason) async {
    await _clearLocalState();
    _messageController.addError(reason);
    if (_onUnauthorized != null) {
      await _onUnauthorized!();
    }
  }

  Future<void> _clearLocalState() async {
    try {
      await _persistenceService.initialize();
      final chatBox = Hive.box<Map>('chat_box');
      await chatBox.clear();
    } catch (_) {}

    try {
      await _tokenStorage.clearTokens();
    } catch (_) {}
  }

  bool _looksUnauthorized(String? message) {
    if (message == null) {
      return false;
    }

    final lower = message.toLowerCase();
    return lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('forbidden') ||
        lower.contains('token');
  }

  void _updateConnectionState(bool connected) {
    if (_isConnected == connected && connectionState.value == connected) {
      return;
    }

    _isConnected = connected;
    connectionState.value = connected;
    _connectionController.add(connected);
  }

  String _payloadKey(String roomId, String messageId) => '$roomId:$messageId';
}
