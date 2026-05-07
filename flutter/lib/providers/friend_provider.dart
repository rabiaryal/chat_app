/// Friend State Management using Provider
import 'package:flutter/foundation.dart';
import '../models/friend.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/friend_persistence_service.dart';

class FriendProvider extends ChangeNotifier {
  final ApiService apiService;
  final _persistenceService = FriendPersistenceService();

  List<Friend> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreFriends = true;
  int _currentPage = 1;
  String? _error;
  List<Friend> _searchResults = [];
  List<Friend> _suggestedUsers = [];
  String _searchQuery = '';

  // Getters
  List<Friend> get friends => _friends;
  List<FriendRequest> get incomingRequests => _incomingRequests;
  List<FriendRequest> get outgoingRequests => _outgoingRequests;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreFriends => _hasMoreFriends;
  String? get error => _error;
  List<Friend> get searchResults => _searchResults;
  List<Friend> get suggestedUsers => _suggestedUsers;
  String get searchQuery => _searchQuery;

  FriendProvider({required this.apiService});

  /// Load all friends (with pagination and caching)
  Future<void> loadFriends({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreFriends = true;
      _isLoading = true;
    } else {
      if (!_hasMoreFriends || _isLoadingMore || _isLoading) return;
      _isLoadingMore = true;
    }
    
    _error = null;
    notifyListeners();

    try {
      // On initial load, try to get cached friends first
      if (refresh && _friends.isEmpty) {
        final cachedUsers = await _persistenceService.getCachedFriends();
        if (cachedUsers.isNotEmpty) {
          _friends = cachedUsers.map((user) => Friend(
            id: user.id,
            username: user.username,
            firstName: user.firstName,
            lastName: user.lastName,
            email: user.email,
            isOnline: user.isOnline,
            lastSeen: user.lastSeen,
          )).toList();
          notifyListeners();
        }
      }

      final userList = await apiService.getFriends(page: _currentPage, limit: 10);
      
      final mappedFriends = userList.map((user) => Friend(
            id: user.id,
            username: user.username,
            firstName: user.firstName,
            lastName: user.lastName,
            email: user.email,
            isOnline: user.isOnline,
            lastSeen: user.lastSeen,
          )).toList();

      if (refresh) {
        _friends = mappedFriends;
        await _persistenceService.replaceFriends(userList);
      } else {
        _friends.addAll(mappedFriends);
        await _persistenceService.appendFriends(userList);
      }

      if (userList.length < 10) {
        _hasMoreFriends = false;
      } else {
        _currentPage++;
      }

      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
      print('✓ Loaded ${_friends.length} friends (Page $_currentPage)');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isLoadingMore = false;
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
  Future<void> loadOutgoingRequests({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final requests = await apiService.getOutgoingFriendRequests();
      _outgoingRequests = requests;
      if (showLoading) _isLoading = false;
      notifyListeners();
      print('✓ Loaded ${_outgoingRequests.length} outgoing requests');
    } catch (e) {
      _error = e.toString();
      if (showLoading) _isLoading = false;
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
        loadFriends(refresh: true),
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
    _error = null;
    notifyListeners();

    try {
      await apiService.sendFriendRequest(targetUserId: targetUserId);
      // Reload outgoing requests quietly
      await loadOutgoingRequests(showLoading: false);
      
      // Remove the successfully requested user from available suggestions/searches
      _suggestedUsers.removeWhere((user) => user.id == targetUserId);
      _searchResults.removeWhere((user) => user.id == targetUserId);
      
      notifyListeners();
      print('✓ Friend request sent');
      return true;
    } catch (e) {
      _error = e.toString();
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
      
      // Sync with Hive cache
      final userList = _friends.map((f) => User(
        id: f.id,
        username: f.username,
        email: f.email,
        firstName: f.firstName,
        lastName: f.lastName,
        isOnline: f.isOnline,
        lastSeen: f.lastSeen,
      )).toList();
      await _persistenceService.replaceFriends(userList);

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
      if (query.isEmpty) {
        _searchResults = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final results = await apiService.searchUsers(query);

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

  /// Load suggested users (for discovering new friends)
  Future<void> loadSuggestedUsers({int page = 1, int limit = 5}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final users = await apiService.getSuggestedUsers(page: page, limit: limit);
      _suggestedUsers = users
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
      print('✓ Loaded ${_suggestedUsers.length} suggested users');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('✗ Failed to load suggested users: $e');
    }
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }
}
