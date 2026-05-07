import 'package:flutter/foundation.dart';
import '../models/chat_room.dart';
import '../services/api_service.dart';

class RoomProvider extends ChangeNotifier {
  final ApiService apiService;

  List<ChatRoom> _rooms = [];
  bool _isLoading = false;
  String? _error;

  RoomProvider({required this.apiService});

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
}
