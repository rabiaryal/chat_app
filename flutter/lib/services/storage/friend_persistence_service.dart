import 'package:hive_flutter/hive_flutter.dart';
import '../../features/auth/models/user.dart';
import 'hive_token_storage.dart';

/// Hive-backed persistence for the user's friend list.
class FriendPersistenceService {
  static const String _boxPrefix = 'cached_friends';

  bool _isInitialized = false;

  /// Ensure Hive box is open
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
  }

  String _boxName([String? userId]) {
    final scope = userId ?? HiveTokenStorage.instance.getCurrentUserId();
    return scope == null ? '${_boxPrefix}_global' : '${_boxPrefix}_$scope';
  }

  Future<Box<Map>> _openBox({String? userId}) async {
    await initialize();
    return await Hive.openBox<Map>(_boxName(userId));
  }

  /// Replace the currently cached friends with a new list
  Future<void> replaceFriends(List<User> friends) async {
    final box = await _openBox();
    await box.clear();

    final Map<dynamic, Map<String, dynamic>> friendsMap = {};
    for (final friend in friends) {
      final json = Map<String, dynamic>.from(friend.toJson());
      // Do not persist volatile presence fields to Hive; keep them runtime-only
      json.remove('is_online');
      json.remove('last_seen');
      friendsMap[friend.id] = json;
    }

    await box.putAll(friendsMap);
  }

  /// Add or update friends in the cache (useful for pagination appending)
  Future<void> appendFriends(List<User> friends) async {
    final box = await _openBox();

    for (final friend in friends) {
      final json = Map<String, dynamic>.from(friend.toJson());
      json.remove('is_online');
      json.remove('last_seen');
      await box.put(friend.id, json);
    }
  }

  /// Retrieve all cached friends
  Future<List<User>> getCachedFriends() async {
    final box = await _openBox();

    final friends = box.values
        .map((value) => User.fromJson(Map<String, dynamic>.from(value)))
        .toList();

    // Sort by isOnline first, then lastSeen descending
    friends.sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;

      final aDate = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return friends;
  }

  /// Clear all cached friends (e.g., on logout)
  Future<void> clearFriends() async {
    final box = await _openBox();
    await box.clear();
  }

  /// Clear only the cache for a specific user id.
  Future<void> clearFriendsForUser(String userId) async {
    final box = await _openBox(userId: userId);
    await box.clear();
  }
}
