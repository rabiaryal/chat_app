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

  void _updateRoomLastMessage(ChatMessage message) {
    final index = _rooms.indexWhere((r) => r.id == message.roomId);
    if (index != -1) {
      final room = _rooms[index];
      _rooms[index] = room.copyWith(
        lastMessage: message.content,
        lastMessageTimestamp: message.timestamp,
        lastMessageSenderId: message.userId,
      );
      
      // Move room to top
      final updatedRoom = _rooms.removeAt(index);
      _rooms.insert(0, updatedRoom);
      
      notifyListeners();
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
