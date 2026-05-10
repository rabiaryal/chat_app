import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';

class RoomProvider extends ChangeNotifier {
  final ApiService apiService;
  final ChatService chatService;
  StreamSubscription? _messageSubscription;

  List<ChatRoom> _rooms = [];
  bool _isLoading = false;
  String? _error;

  RoomProvider({
    required this.apiService,
    required this.chatService,
  }) {
    _initMessageListener();
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
        _rooms[index] = room.copyWith(
          lastMessage: message.content,
          lastMessageTimestamp: message.timestamp,
          lastMessageSenderId: message.userId,
          unreadCount: room.unreadCount + 1,
        );

        // Move to top
        final updatedRoom = _rooms.removeAt(index);
        _rooms.insert(0, updatedRoom);
        notifyListeners();
      }
    } else {
      // NEW: If room not found, it might be a new connection/friendship
      // Fetch the room details from API and add it
      try {
        final response = await apiService.dio.get('/api/v1/rooms/${message.roomId}/');
        if (response.statusCode == 200) {
          final newRoom = ChatRoom.fromJson(response.data);
          _rooms.insert(0, newRoom);
          notifyListeners();
          print('✓ New room discovered and added: ${newRoom.name}');
        }
      } catch (e) {
        print('✗ Failed to fetch new room details: $e');
      }
    }
  }

  Future<void> markRoomAsRead(String roomId) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final oldUnreadCount = _rooms[index].unreadCount;
      _rooms[index] = _rooms[index].copyWith(unreadCount: 0);
      notifyListeners();

      if (oldUnreadCount > 0) {
        try {
          await apiService.dio.post('/api/v1/rooms/$roomId/read/');
          print('✓ Room $roomId marked as read on server');
        } catch (e) {
          print('✗ Failed to mark room as read on server: $e');
        }
      }
    }
  }

  List<ChatRoom> get rooms => _rooms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rooms = await apiService.getRooms();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load rooms: $e');
    }
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
