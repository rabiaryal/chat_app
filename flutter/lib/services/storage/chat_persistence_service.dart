import 'package:hive_flutter/hive_flutter.dart';
import '../../models/message_model.dart';
import 'hive_token_storage.dart';

/// Hive-backed persistence for recent chat messages.
class ChatPersistenceService {
  static const int maxMessages = 20;
  static const String _boxName = 'chat_box';

  /// Hive is initialized by the app bootstrap through token storage.
  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Map>(_boxName);
    }
  }

  Box<Map> _box() {
    return Hive.box<Map>(_boxName);
  }

  Future<Box<Map>> _openRoomBox(String roomId) async {
    await initialize();
    return _box();
  }

  Future<void> addMessage(String roomId, MessageModel message) async {
    final box = await _openRoomBox(roomId);
    await box.put(_messageKey(roomId, message.id), message.toJson());
    await _trimToLimit(roomId, box);
  }

  Future<void> upsertMessage(String roomId, MessageModel message) async {
    await addMessage(roomId, message);
  }

  Future<List<MessageModel>> getMessages(
    String roomId, {
    Future<List<MessageModel>> Function()? recoveryCallback,
  }) async {
    final box = await _openRoomBox(roomId);
    final cachedMessages = _readMessages(roomId, box);

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
    await _clearRoom(roomId, box);

    final orderedMessages = [...messages]..sort(
        (left, right) => left.timestamp.compareTo(right.timestamp),
      );

    final latestMessages = orderedMessages.length > maxMessages
        ? orderedMessages.sublist(orderedMessages.length - maxMessages)
        : orderedMessages;

    for (final message in latestMessages) {
      await box.put(_messageKey(roomId, message.id), message.toJson());
    }

    await _trimToLimit(roomId, box);
  }

  Future<void> clearRoomMessages(String roomId) async {
    final box = await _openRoomBox(roomId);
    await _clearRoom(roomId, box);
  }

  /// Clear all cached messages for a specific user.
  Future<void> clearMessagesForUser(String userId) async {
    final box = await _openRoomBox('global');

    final keysToDelete = box.keys.where((key) {
      final raw = box.get(key);
      if (raw == null) {
        return false;
      }
      final messageId = key.toString();
      return messageId.startsWith('u:$userId:');
    }).toList();

    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }

  List<MessageModel> _readMessages(String roomId, Box<Map> box) {
    final messages = box.values
        .map((value) => MessageModel.fromJson(Map<String, dynamic>.from(value)))
        .where((message) => message.roomId == roomId)
        .toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

    return messages;
  }

  Future<void> _trimToLimit(String roomId, Box<Map> box) async {
    while (_countRoomMessages(roomId, box) > maxMessages) {
      final oldestEntry = box.toMap().entries.where((entry) {
        final value = Map<String, dynamic>.from(entry.value);
        return value['room_id']?.toString() == roomId;
      }).toList()
        ..sort((left, right) {
          final leftTime = DateTime.tryParse(
                Map<String, dynamic>.from(left.value)['timestamp']
                        ?.toString() ??
                    '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final rightTime = DateTime.tryParse(
                Map<String, dynamic>.from(right.value)['timestamp']
                        ?.toString() ??
                    '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return leftTime.compareTo(rightTime);
        });

      if (oldestEntry.isEmpty) {
        return;
      }

      await box.delete(oldestEntry.first.key);
    }
  }

  int _countRoomMessages(String roomId, Box<Map> box) {
    return box.values
        .map((value) => MessageModel.fromJson(Map<String, dynamic>.from(value)))
        .where((message) => message.roomId == roomId)
        .length;
  }

  Future<void> _clearRoom(String roomId, Box<Map> box) async {
    final keysToDelete = box.keys.where((key) {
      final raw = box.get(key);
      if (raw == null) {
        return false;
      }
      final value = Map<String, dynamic>.from(raw);
      return value['room_id']?.toString() == roomId;
    }).toList();

    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }

  /// Update message ID when server confirms it
  Future<void> updateMessageId(
    String roomId,
    String oldId,
    MessageModel updatedMessage,
  ) async {
    final box = await _openRoomBox(roomId);
    final oldKey = _messageKey(roomId, oldId);
    if (box.containsKey(oldKey)) {
      await box.delete(oldKey);
    }
    await box.put(
        _messageKey(roomId, updatedMessage.id), updatedMessage.toJson());
  }

  /// Mark a message as read in the local Hive box
  Future<void> markMessageAsRead(String roomId, String messageId) async {
    final box = await _openRoomBox(roomId);
    final data = box.get(_messageKey(roomId, messageId));
    if (data != null) {
      final json = Map<String, dynamic>.from(data);
      json['is_seen'] = true;
      json['is_read'] = true;
      json['status'] = 'read';
      json['is_pending'] = false;
      await box.put(_messageKey(roomId, messageId), json);
    }
  }

  Future<MessageModel?> findMatchingMessage({
    required String roomId,
    required int userId,
    required String text,
    Duration within = const Duration(seconds: 10),
  }) async {
    final box = await _openRoomBox(roomId);
    final now = DateTime.now();

    final matches = box.values
        .map((value) => MessageModel.fromJson(Map<String, dynamic>.from(value)))
        .where((message) =>
            message.roomId == roomId &&
            message.userId == userId &&
            message.text == text &&
            now.difference(message.timestamp).abs() <= within)
        .toList()
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));

    if (matches.isEmpty) {
      return null;
    }

    return matches.first;
  }

  String _messageKey(String roomId, String messageId) {
    final userScope = HiveTokenStorage.instance.getCurrentUserId() ?? 'global';
    return 'u:$userScope:room:$roomId:msg:$messageId';
  }
}
