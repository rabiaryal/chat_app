import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../../utils/snackbar_utils.dart';
import 'package:go_router/go_router.dart';

class SuggestedFriendsScreen extends ConsumerStatefulWidget {
  const SuggestedFriendsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SuggestedFriendsScreen> createState() =>
      _SuggestedFriendsScreenState();
}

class _SuggestedFriendsScreenState
    extends ConsumerState<SuggestedFriendsScreen> {
  final Set<int> _addedUserIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider>().loadSuggestedUsers(limit: 10);
    });
  }

  Future<void> _sendRequest(int userId) async {
    setState(() => _addedUserIds.add(userId));
    final success =
        await context.read<FriendProvider>().sendFriendRequest(userId);

    if (mounted) {
      if (success) {
        SnackbarUtils.showSuccess(context, 'Friend request sent!');
      } else {
        setState(() => _addedUserIds.remove(userId));
        final error = context.read<FriendProvider>().error;
        SnackbarUtils.showError(
            context, error ?? 'Failed to send friend request');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final friendProvider = context.watch<FriendProvider>();
    final suggestions = friendProvider.suggestedUsers;
    final isLoading = friendProvider.isLoading;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Find Friends',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).completeOnboarding();
              context.go('/chat-list');
            },
            child: const Text('Skip',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'People you may know',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Send a friend request to start chatting.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : suggestions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final friend = suggestions[index];
                          final userId = friend.id;
                          final username = friend.username;
                          final displayName = friend.displayName;
                          final isAdded = _addedUserIds.contains(userId);
                          final initial = username.trim().isNotEmpty
                              ? username.trim()[0].toUpperCase()
                              : '?';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      primaryColor.withOpacity(0.12),
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(username,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Text(displayName,
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13)),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.people_outline,
                                              size: 13,
                                              color: Colors.grey[400]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Suggested for you',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isAdded
                                      ? null
                                      : () => _sendRequest(userId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAdded
                                        ? Colors.grey[200]
                                        : primaryColor,
                                    foregroundColor:
                                        isAdded ? Colors.grey : Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(isAdded ? '✓ Sent' : 'Add'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(authProvider.notifier).completeOnboarding();
                  context.go('/chat-list');
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Go to Chats',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text('No suggestions right now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'As more people join, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () =>
                context.read<FriendProvider>().loadSuggestedUsers(limit: 10),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
