import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';

/// Hive-backed persistence for the user's friend list.
class FriendPersistenceService {
  static const String _boxName = 'cached_friends';

  bool _isInitialized = false;

  /// Ensure Hive box is open
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
  }

  Future<Box<Map>> _openBox() async {
    await initialize();
    return await Hive.openBox<Map>(_boxName);
  }

  /// Replace the currently cached friends with a new list
  Future<void> replaceFriends(List<User> friends) async {
    final box = await _openBox();
    await box.clear();

    // Map the user ID to their JSON representation
    final Map<dynamic, Map<String, dynamic>> friendsMap = {};
    for (final friend in friends) {
      friendsMap[friend.id] = friend.toJson();
    }

    await box.putAll(friendsMap);
  }

  /// Add or update friends in the cache (useful for pagination appending)
  Future<void> appendFriends(List<User> friends) async {
    final box = await _openBox();

    for (final friend in friends) {
      await box.put(friend.id, friend.toJson());
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
      return bDate.compareTo(aDate); // Descending
    });

    return friends;
  }

  /// Clear all cached friends (e.g., on logout)
  Future<void> clearFriends() async {
    final box = await _openBox();
    await box.clear();
  }
}
