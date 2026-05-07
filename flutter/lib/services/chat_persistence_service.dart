import 'package:hive_flutter/hive_flutter.dart';

import '../models/message_model.dart';

/// Hive-backed persistence for recent chat messages.
class ChatPersistenceService {
  static const int maxMessages = 20;
  static const String _boxPrefix = 'chat_messages_';

  final Map<String, Box<Map>> _roomBoxes = {};
  bool _isInitialized = false;

  /// Hive is initialized by the app bootstrap through token storage.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
  }

  Future<Box<Map>> _openRoomBox(String roomId) async {
    await initialize();

    final existingBox = _roomBoxes[roomId];
    if (existingBox != null) {
      return existingBox;
    }

    final box = await Hive.openBox<Map>('$_boxPrefix$roomId');
    _roomBoxes[roomId] = box;
    return box;
  }

  Future<void> addMessage(String roomId, MessageModel message) async {
    final box = await _openRoomBox(roomId);
    await box.put(message.id, message.toJson());
    await _trimToLimit(box);
  }

  Future<List<MessageModel>> getMessages(
    String roomId, {
    Future<List<MessageModel>> Function()? recoveryCallback,
  }) async {
    final box = await _openRoomBox(roomId);
    final cachedMessages = _readMessages(box);

    if (cachedMessages.isNotEmpty) {
      return cachedMessages;
    }

    if (recoveryCallback == null) {
      return cachedMessages;
    }

    final recoveredMessages = await recoveryCallback();
    if (recoveredMessages.isNotEmpty) {
      await replaceMessages(roomId, recoveredMessages);
    }

    return recoveredMessages;
  }

  Future<void> replaceMessages(
    String roomId,
    List<MessageModel> messages,
  ) async {
    final box = await _openRoomBox(roomId);
    await box.clear();

    final orderedMessages = [...messages]..sort(
        (left, right) => left.timestamp.compareTo(right.timestamp),
      );

    final latestMessages = orderedMessages.length > maxMessages
        ? orderedMessages.sublist(orderedMessages.length - maxMessages)
        : orderedMessages;

    for (final message in latestMessages) {
      await box.put(message.id, message.toJson());
    }

    await _trimToLimit(box);
  }

  Future<void> clearRoomMessages(String roomId) async {
    final box = await _openRoomBox(roomId);
    await box.clear();
  }

  List<MessageModel> _readMessages(Box<Map> box) {
    final messages = box.values
        .map((value) => MessageModel.fromJson(Map<String, dynamic>.from(value)))
        .toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

    return messages;
  }

  Future<void> _trimToLimit(Box<Map> box) async {
    while (box.length > maxMessages) {
      final oldestKey = box.keys.first;
      await box.delete(oldestKey);
    }
  }

  /// Update message ID when server confirms it
  /// Deletes old local message and saves with new server ID
  Future<void> updateMessageId(
    String roomId,
    String oldId,
    MessageModel updatedMessage,
  ) async {
    final box = await _openRoomBox(roomId);
    if (box.containsKey(oldId)) {
      await box.delete(oldId);
    }
    await box.put(updatedMessage.id, updatedMessage.toJson());
  }
}
