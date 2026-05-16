import 'dart:async';

import '../../models/chat_message.dart';
import '../api_service.dart';
import 'encryption_service.dart';
import 'socket_service.dart';

/// Compatibility facade for the realtime chat layer.
class ChatService {
  final ApiService apiService;
  late final SocketService _socketService;

  ChatService({
    required this.apiService,
    EncryptionService? encryptionService,
  }) {
    _socketService = SocketService(
      apiService: apiService,
      tokenStorage: apiService.tokenStorage,
      encryptionService: encryptionService,
    );
  }

  Stream<ChatMessage> get messageStream => _socketService.messageStream;
  Stream<bool> get connectionStream => _socketService.connectionStream;
  bool get isConnected => _socketService.isConnected;
  String? get currentRoomId => _socketService.currentRoomId;

  Future<bool> restoreSession() async {
    final result = await apiService.restoreSession().run();
    return result.getOrElse((_) => false);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final result =
        await apiService.login(username: username, password: password).run();

    return result.fold(
      (failure) => throw Exception(failure.message),
      (authResponse) => {
        'user': authResponse.user,
        'access': authResponse.accessToken,
        'refresh': authResponse.refreshToken,
      },
    );
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final result = await apiService
        .register(
          username: username,
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
        )
        .run();

    return result.fold(
      (failure) => throw Exception(failure.message),
      (_) async => await login(username: username, password: password),
    );
  }

  Future<void> connectWebSocket({
    required String roomId,
    String? token,
  }) async {
    await _socketService.connect(roomId: roomId);
  }

  void sendTextMessage({
    required String content,
    required String roomId,
    required int userId,
    required String username,
  }) {
    final localMessage = ChatMessage.local(
      content: content,
      userId: userId,
      username: username,
      roomId: roomId,
    );

    unawaited(_socketService.sendTextMessage(message: localMessage));
  }

  Future<void> sendSecureMessage({
    required String content,
    required String roomId,
    required int recipientId,
  }) async {
    final localMessage = ChatMessage.local(
      content: content,
      userId: recipientId,
      username: 'Secure Message',
      roomId: roomId,
      isBot: false,
    );

    unawaited(_socketService.sendSecureMessage(message: localMessage));
  }

  void requestAIResponse({
    required String content,
    required String roomId,
    required int userId,
    required String username,
  }) {
    final localMessage = ChatMessage.local(
      content: content,
      userId: userId,
      username: username,
      roomId: roomId,
      isBot: true,
    );

    unawaited(_socketService.requestAIResponse(message: localMessage));
  }

  void sendTypingIndicator(String roomId) {
    _socketService.sendTypingIndicator(roomId);
  }

  void sendMarkRead(String roomId, String messageId) {
    _socketService.sendMarkRead(roomId, messageId);
  }

  Future<void> disconnectWebSocket() async {
    await _socketService.disconnect();
  }

  Future<void> setupE2EE() async {
    try {
      final encryptionService = EncryptionService();
      String? publicKey = await encryptionService.getLocalPublicKey();

      if (publicKey == null) {
        final keys = await encryptionService.generateKeyPair();
        publicKey = keys['publicKey'];
      }

      if (publicKey != null) {
        await apiService.uploadPublicKey(publicKey, 'mobile-device-1').run();
      }
    } catch (error) {
      print('✗ E2EE Setup error: $error');
    }
  }

  Future<void> logout() async {
    await disconnectWebSocket();
    await apiService.logout().run();
  }

  Future<void> dispose() async {
    await _socketService.dispose();
  }
}
