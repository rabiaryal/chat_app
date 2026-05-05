/// Room State Management using Provider
import 'package:flutter/foundation.dart';
import '../models/chat_room.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class RoomProvider extends ChangeNotifier {
  final ApiService apiService;

  List<ChatRoom> _rooms = [];
  ChatRoom? _selectedRoom;
  bool _isLoading = false;
  String? _error;
  List<User> _searchResults = [];

  // Getters
  List<ChatRoom> get rooms => _rooms;
  ChatRoom? get selectedRoom => _selectedRoom;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<User> get searchResults => _searchResults;

  RoomProvider({required this.apiService});

  /// Fetch all rooms user is a member of
  Future<void> loadRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use the new friend-based room system
      final rooms = await apiService.getRooms();
      _rooms = rooms;
      _isLoading = false;
      notifyListeners();
      print('✓ Loaded ${_rooms.length} rooms');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load rooms: $e');
    }
  }

  /// Create direct message room with a friend (lazy creation)
  Future<bool> createDirectRoom({required int friendId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.getOrCreateDirectRoom(friendId);

      // Reload rooms to get the new one
      await loadRooms();
      _isLoading = false;
      notifyListeners();
      print('✓ Direct message room created with friend $friendId');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to create direct room: $e');
      return false;
    }
  }

  // DEPRECATED: Following methods are not supported in the new friend-based direct messaging system

  /// Select a room (not fully supported in friend-based system)
  /*
  Future<void> selectRoom(String roomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedRoom = await apiService.getRoomDetails(roomId: roomId);
      _isLoading = false;
      notifyListeners();
      print('✓ Loaded room: ${_selectedRoom?.name}');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load room details: $e');
    }
  }

  /// Delete a room (creator only)
  Future<bool> deleteRoom(String roomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.deleteRoom(roomId: roomId);
      _rooms.removeWhere((room) => room.id == roomId);
      if (_selectedRoom?.id == roomId) {
        _selectedRoom = null;
      }
      _isLoading = false;
      notifyListeners();
      print('✓ Room deleted');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to delete room: $e');
      return false;
    }
  }

  /// Add member to room
  Future<bool> addRoomMember(String roomId, int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.addRoomMember(roomId: roomId, userId: userId);
      // Reload room to get updated member list
      if (_selectedRoom?.id == roomId) {
        await selectRoom(roomId);
      }
      _isLoading = false;
      notifyListeners();
      print('✓ Member added to room');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to add member: $e');
      return false;
    }
  }

  /// Remove member from room
  Future<bool> removeRoomMember(String roomId, int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.removeRoomMember(roomId: roomId, userId: userId);
      // Reload room to get updated member list
      if (_selectedRoom?.id == roomId) {
        await selectRoom(roomId);
      }
      _isLoading = false;
      notifyListeners();
      print('✓ Member removed from room');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to remove member: $e');
      return false;
    }
  }

  /// Leave a room
  Future<bool> leaveRoom(String roomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.leaveRoom(roomId: roomId);
      _rooms.removeWhere((room) => room.id == roomId);
      if (_selectedRoom?.id == roomId) {
        _selectedRoom = null;
      }
      _isLoading = false;
      notifyListeners();
      print('✓ Left room');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to leave room: $e');
      return false;
    }
  }
  */

  /// Search users by username
  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await apiService.searchUsers(query);
      _searchResults = result;
      _isLoading = false;
      notifyListeners();
      print('✓ Found ${_searchResults.length} users');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ User search failed: $e');
    }
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    _error = null;
    notifyListeners();
  }

  /// Clear selected room
  void clearSelectedRoom() {
    _selectedRoom = null;
    notifyListeners();
  }
}
