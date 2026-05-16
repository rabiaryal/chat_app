import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/realtime/chat_service.dart';
import '../constants/api_constant.dart';

class RoomProvider extends ChangeNotifier {
  final ApiService apiService;
  final ChatService chatService;
  StreamSubscription? _messageSubscription;

  List<ChatRoom> _rooms = [];
  bool _isLoading = false;
  String? _error;
  int? _currentUserId; // Track logged-in user to avoid false unread counts

  RoomProvider({
    required this.apiService,
    required this.chatService,
  }) {
    _initMessageListener();
  }

  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  void _initMessageListener() {
    _messageSubscription = chatService.messageStream.listen((message) {
      _updateRoomLastMessage(message);
    });
  }

  Future<void> _updateRoomLastMessage(ChatMessage message) async {
    final index = _rooms.indexWhere((r) => r.id == message.roomId);

    if (index != -1) {
      final room = _rooms[index];

      // If it's a read receipt, decrement unread count
      if (message.status == MessageStatus.read) {
        if (room.unreadCount > 0) {
          _rooms[index] = room.copyWith(
            unreadCount: room.unreadCount > 0 ? room.unreadCount - 1 : 0,
          );
          notifyListeners();
        }
        return;
      }

      // Update existing room
      if (message.content.isNotEmpty) {
        // *** FIX: Don't increment unread for messages the current user sent ***
        final isOwnMessage =
            _currentUserId != null && message.userId == _currentUserId;
        _rooms[index] = room.copyWith(
          lastMessage: message.content,
          lastMessageTimestamp: message.timestamp,
          lastMessageSenderId: message.userId,
          unreadCount: isOwnMessage ? room.unreadCount : room.unreadCount + 1,
        );

        // Move to top
        final updatedRoom = _rooms.removeAt(index);
        _rooms.insert(0, updatedRoom);
        notifyListeners();
      }
    } else {
      // NEW: If room not found, it might be a new connection/friendship
      // Fetch the room details from API and add it
      final result = await apiService.getRoom(message.roomId).run();
      result.fold(
        (failure) => print('✗ Failed to fetch new room details: ${failure.message}'),
        (newRoom) {
          _rooms.insert(0, newRoom);
          notifyListeners();
          print('✓ New room discovered and added: ${newRoom.name}');
        },
      );
    }
  }

  Future<void> markRoomAsRead(String roomId) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final oldUnreadCount = _rooms[index].unreadCount;
      _rooms[index] = _rooms[index].copyWith(unreadCount: 0);
      notifyListeners();

      if (oldUnreadCount > 0) {
        final result = await apiService.markRoomAsRead(roomId).run();
        result.fold(
          (failure) => print('✗ Failed to mark room as read on server: ${failure.message}'),
          (_) => print('✓ Room $roomId marked as read on server'),
        );
      }
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final result = await apiService.leaveRoom(roomId).run();
    result.fold(
      (failure) {
        print('✗ Failed to delete room: ${failure.message}');
        _error = failure.message;
        notifyListeners();
      },
      (_) {
        _rooms.removeWhere((r) => r.id == roomId);
        notifyListeners();
        print('✓ Room $roomId deleted');
      },
    );
  }

  Future<void> addMember(String roomId, int userId) async {
    final result = await apiService.addRoomMember(roomId: roomId, userId: userId).run();
    result.fold(
      (failure) {
        print('✗ Failed to add member: ${failure.message}');
        _error = failure.message;
        notifyListeners();
      },
      (_) => print('✓ Member $userId added to room $roomId'),
    );
  }

  Future<void> removeMember(String roomId, int userId) async {
    final result = await apiService.removeRoomMember(roomId: roomId, userId: userId).run();
    result.fold(
      (failure) {
        print('✗ Failed to remove member: ${failure.message}');
        _error = failure.message;
        notifyListeners();
      },
      (resp) {
        print('✓ Member $userId removed from room $roomId — server responded: ${resp['message'] ?? ''}');
        notifyListeners();
      },
    );
  }

  List<ChatRoom> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService.getRooms().run();
    result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to load rooms: ${failure.message}');
      },
      (rooms) {
        _rooms = rooms;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void addRoom(ChatRoom room) {
    _rooms.insert(0, room);
    notifyListeners();
  }

  void updateRoom(ChatRoom updatedRoom) {
    final index = _rooms.indexWhere((r) => r.id == updatedRoom.id);
    if (index != -1) {
      _rooms[index] = updatedRoom;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
