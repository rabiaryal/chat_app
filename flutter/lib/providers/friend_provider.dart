/// Friend State Management using Provider
import 'package:flutter/foundation.dart';
import '../models/friend.dart';
import '../features/auth/models/user.dart';
import '../services/api_service.dart';
import '../services/storage/friend_persistence_service.dart';

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

    // On initial load, try to get cached friends first
    if (refresh && _friends.isEmpty) {
      final cachedUsers = await _persistenceService.getCachedFriends();
      if (cachedUsers.isNotEmpty) {
        _friends = cachedUsers
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
        notifyListeners();
      }
    }

    final result =
        await apiService.getFriends(page: _currentPage, limit: 10).run();

    result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
        print('✗ Failed to load friends: ${failure.message}');
      },
      (userList) async {
        final mappedFriends = userList
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
      },
    );
  }

  /// Load incoming friend requests
  Future<void> loadIncomingRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService.getIncomingFriendRequests().run();

    result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to load incoming requests: ${failure.message}');
      },
      (requests) {
        _incomingRequests = requests;
        _isLoading = false;
        notifyListeners();
        print('✓ Loaded ${_incomingRequests.length} incoming requests');
      },
    );
  }

  /// Load outgoing friend requests
  Future<void> loadOutgoingRequests({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    final result = await apiService.getOutgoingFriendRequests().run();

    result.fold(
      (failure) {
        _error = failure.message;
        if (showLoading) _isLoading = false;
        notifyListeners();
        print('✗ Failed to load outgoing requests: ${failure.message}');
      },
      (requests) {
        _outgoingRequests = requests;
        if (showLoading) _isLoading = false;
        notifyListeners();
        print('✓ Loaded ${_outgoingRequests.length} outgoing requests');
      },
    );
  }

  /// Load all friend data (friends and requests)
  Future<void> loadAllFriendsData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await loadFriends(refresh: true);
    await loadIncomingRequests();
    await loadOutgoingRequests();

    _isLoading = false;
    notifyListeners();
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(int targetUserId) async {
    _error = null;
    notifyListeners();

    final result =
        await apiService.sendFriendRequest(targetUserId: targetUserId).run();

    return result.fold(
      (failure) {
        _error = failure.message;
        notifyListeners();
        print('✗ Failed to send friend request: ${failure.message}');
        return false;
      },
      (_) async {
        // Reload outgoing requests quietly
        await loadOutgoingRequests(showLoading: false);

        // Remove the successfully requested user from available suggestions/searches
        _suggestedUsers.removeWhere((user) => user.id == targetUserId);
        _searchResults.removeWhere((user) => user.id == targetUserId);

        notifyListeners();
        print('✓ Friend request sent');
        return true;
      },
    );
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(int requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService.acceptFriendRequest(requestId).run();

    return result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to accept friend request: ${failure.message}');
        return false;
      },
      (_) async {
        // Reload data
        await loadAllFriendsData();
        _isLoading = false;
        notifyListeners();
        print('✓ Friend request accepted');
        return true;
      },
    );
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(int requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService.rejectFriendRequest(requestId).run();

    return result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to reject friend request: ${failure.message}');
        return false;
      },
      (_) async {
        // Reload data
        await loadAllFriendsData();
        _isLoading = false;
        notifyListeners();
        print('✓ Friend request rejected');
        return true;
      },
    );
  }

  /// Remove a friend
  Future<bool> removeFriend(int friendId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await apiService.removeFriend(friendId).run();

    return result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to remove friend: ${failure.message}');
        return false;
      },
      (_) async {
        _friends.removeWhere((friend) => friend.id == friendId);

        // Sync with Hive cache
        final userList = _friends
            .map((f) => User(
                  id: f.id,
                  username: f.username,
                  email: f.email,
                  firstName: f.firstName,
                  lastName: f.lastName,
                  isOnline: f.isOnline,
                  lastSeen: f.lastSeen,
                ))
            .toList();
        await _persistenceService.replaceFriends(userList);

        _isLoading = false;
        notifyListeners();
        print('✓ Friend removed');
        return true;
      },
    );
  }

  /// Search for users
  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (query.isEmpty) {
      _searchResults = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    final result = await apiService.searchUsers(query).run();

    result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to search users: ${failure.message}');
      },
      (results) {
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
      },
    );
  }

  /// Load suggested users (for discovering new friends)
  Future<void> loadSuggestedUsers({int page = 1, int limit = 5}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result =
        await apiService.getSuggestedUsers(page: page, limit: limit).run();

    result.fold(
      (failure) {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
        print('✗ Failed to load suggested users: ${failure.message}');
      },
      (users) {
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
      },
    );
  }

  /// Check if a user is online
  bool isUserOnline(int userId) {
    try {
      return _friends.firstWhere((f) => f.id == userId).isOnline;
    } catch (_) {
      return false;
    }
  }

  /// Update presence for a friend (called from realtime presence events)
  void updatePresence(int userId, bool isOnline, DateTime? lastSeen) {
    final idx = _friends.indexWhere((f) => f.id == userId);
    if (idx == -1) return;

    final f = _friends[idx];
    final updated = Friend(
      id: f.id,
      username: f.username,
      firstName: f.firstName,
      lastName: f.lastName,
      email: f.email,
      isOnline: isOnline,
      lastSeen: lastSeen ?? f.lastSeen,
      avatar: f.avatar,
    );

    _friends[idx] = updated;
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }
}
