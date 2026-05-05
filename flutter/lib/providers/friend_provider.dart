/// Friend State Management using Provider
import 'package:flutter/foundation.dart';
import '../models/friend.dart';
import '../services/api_service.dart';

class FriendProvider extends ChangeNotifier {
  final ApiService apiService;

  List<Friend> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  bool _isLoading = false;
  String? _error;
  List<Friend> _searchResults = [];
  String _searchQuery = '';

  // Getters
  List<Friend> get friends => _friends;
  List<FriendRequest> get incomingRequests => _incomingRequests;
  List<FriendRequest> get outgoingRequests => _outgoingRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Friend> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;

  FriendProvider({required this.apiService});

  /// Load all friends
  Future<void> loadFriends() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userList = await apiService.getFriends();
      _friends = userList
          .map((user) => Friend(
                id: user.id,
                username: user.username,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                isOnline: user.isOnline,
                lastSeen: user.lastSeen,
              ))
          .toList();
      _isLoading = false;
      notifyListeners();
      print('✓ Loaded ${_friends.length} friends');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load friends: $e');
    }
  }

  /// Load incoming friend requests
  Future<void> loadIncomingRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requests = await apiService.getIncomingFriendRequests();
      _incomingRequests = requests;
      _isLoading = false;
      notifyListeners();
      print('✓ Loaded ${_incomingRequests.length} incoming requests');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load incoming requests: $e');
    }
  }

  /// Load outgoing friend requests
  Future<void> loadOutgoingRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requests = await apiService.getOutgoingFriendRequests();
      _outgoingRequests = requests;
      _isLoading = false;
      notifyListeners();
      print('✓ Loaded ${_outgoingRequests.length} outgoing requests');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load outgoing requests: $e');
    }
  }

  /// Load all friend data (friends and requests)
  Future<void> loadAllFriendsData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadFriends(),
        loadIncomingRequests(),
        loadOutgoingRequests(),
      ]);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load friend data: $e');
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(int targetUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.sendFriendRequest(targetUserId: targetUserId);
      // Reload outgoing requests
      await loadOutgoingRequests();
      _isLoading = false;
      notifyListeners();
      print('✓ Friend request sent');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to send friend request: $e');
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(int requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.acceptFriendRequest(requestId);
      // Reload data
      await loadAllFriendsData();
      _isLoading = false;
      notifyListeners();
      print('✓ Friend request accepted');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to accept friend request: $e');
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(int requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.rejectFriendRequest(requestId);
      // Reload data
      await loadAllFriendsData();
      _isLoading = false;
      notifyListeners();
      print('✓ Friend request rejected');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to reject friend request: $e');
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(int friendId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.removeFriend(friendId);
      _friends.removeWhere((friend) => friend.id == friendId);
      _isLoading = false;
      notifyListeners();
      print('✓ Friend removed');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to remove friend: $e');
      return false;
    }
  }

  /// Search for users
  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use getAllUsers when query is empty, otherwise search
      final results = query.isEmpty
          ? await apiService.getAllUsers()
          : await apiService.searchUsers(query);

      _searchResults = results
          .map((user) => Friend(
                id: user.id,
                username: user.username,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                isOnline: user.isOnline,
                lastSeen: user.lastSeen,
              ))
          .toList();
      _isLoading = false;
      notifyListeners();
      print('✓ Found ${_searchResults.length} users matching "$query"');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to search users: $e');
    }
  }

  /// Load all available users (for discovering new friends)
  Future<void> loadAvailableUsers() async {
    _isLoading = true;
    _error = null;
    _searchQuery = '';
    notifyListeners();

    try {
      final users = await apiService.getAllUsers();
      _searchResults = users
          .map((user) => Friend(
                id: user.id,
                username: user.username,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                isOnline: user.isOnline,
                lastSeen: user.lastSeen,
              ))
          .toList();
      _isLoading = false;
      notifyListeners();
      print('✓ Loaded ${_searchResults.length} available users');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load available users: $e');
    }
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }
}
