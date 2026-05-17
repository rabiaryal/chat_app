import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime presence state: a set of online user IDs kept in memory.
class PresenceNotifier extends StateNotifier<Set<int>> {
  PresenceNotifier() : super({});

  void setOnline(int userId) {
    if (state.contains(userId)) return;
    state = {...state, userId};
  }

  void setOffline(int userId) {
    if (!state.contains(userId)) return;
    final copy = Set<int>.from(state);
    copy.remove(userId);
    state = copy;
  }

  void setSnapshot(Set<int> userIds) {
    state = Set<int>.from(userIds);
  }

  void clear() {
    state = {};
  }
}

final presenceProvider = StateNotifierProvider<PresenceNotifier, Set<int>>(
    (ref) => PresenceNotifier());
