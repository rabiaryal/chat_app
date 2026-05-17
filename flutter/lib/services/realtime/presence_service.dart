import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api_service.dart';

class PresenceSocketService {
  final ApiService apiService;

  final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming presence messages (payloads delivered by server)
  Stream<Map<String, dynamic>> get onPresence => _incomingController.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  bool _connected = false;
  String? _currentToken;

  PresenceSocketService({required this.apiService});

  Future<void> connect() async {
    final token = apiService.tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      return;
    }

    if (_connected && _currentToken == token && _channel != null) {
      return;
    }

    await disconnect();

    final wsUri = _buildWebSocketUri(token);
    _currentToken = token;
    _channel = WebSocketChannel.connect(wsUri);
    _subscription = _channel!.stream.listen(
      _handleMessage,
      onError: (_) => disconnect(),
      onDone: () => disconnect(),
    );

    _connected = true;
    _sendPing();
    _pingTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => _sendPing());
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _connected = false;

    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _currentToken = null;
    _closeStreams();
  }

  /// Close internal streams when disconnecting
  void _closeStreams() {
    try {
      _incomingController.close();
    } catch (_) {}
  }

  void _sendPing() {
    if (!_connected || _channel == null) {
      return;
    }

    _channel!.sink.add(jsonEncode({'type': 'ping'}));
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final msg = jsonDecode(rawMessage as String);
      final type = msg['type'];
      if (type == 'presence_delta' || type == 'presence_snapshot') {
        final payload = msg['payload'] as Map<String, dynamic>? ?? {};
        _incomingController.add({'type': type, 'payload': payload});
        return;
      }
      // ignore other messages (pong etc.)
    } catch (_) {
      // ignore parse errors
    }
  }

  Uri _buildWebSocketUri(String token) {
    final baseUri = Uri.parse(apiService.baseUrl);
    final scheme = baseUri.scheme == 'https'
        ? 'wss'
        : baseUri.scheme == 'http'
            ? 'ws'
            : baseUri.scheme;

    return Uri(
      scheme: scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/ws/presence/',
      queryParameters: {'token': token},
    );
  }
}
