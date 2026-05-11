import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/snackbar_utils.dart';

class SuggestedFriendsScreen extends StatefulWidget {
  const SuggestedFriendsScreen({Key? key}) : super(key: key);

  @override
  State<SuggestedFriendsScreen> createState() => _SuggestedFriendsScreenState();
}

class _SuggestedFriendsScreenState extends State<SuggestedFriendsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = true;
  final Set<int> _addedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.dio.get(
        '/api/v1/users/suggested/',
        queryParameters: {'limit': 10},
      );

      dynamic data = response.data;
      List results = [];

      if (data is Map) {
        results = data['results'] ?? [];
      } else if (data is List) {
        results = data;
      }

      setState(() {
        _suggestions = results.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading suggestions: $e');
    }
  }

  Future<void> _sendRequest(int userId) async {
    setState(() => _addedUserIds.add(userId));
    try {
      final response = await _apiService.dio.post(
        '/api/v1/friendship/request/',
        data: {'target_user_id': userId},
      );
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : 'Friend request sent!',
        );
      }
    } catch (e) {
      setState(() => _addedUserIds.remove(userId));
      if (mounted) {
        SnackbarUtils.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

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
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/chat-list'),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _suggestions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final raw = _suggestions[index];
                          final userId = raw['id'] as int? ?? 0;
                          final username = raw['username'] as String? ?? '';
                          final firstName = raw['first_name'] as String? ?? '';
                          final lastName = raw['last_name'] as String? ?? '';
                          final mutualCount =
                              raw['mutual_friends'] as int? ?? 0;
                          final isAdded = _addedUserIds.contains(userId);
                          final displayName =
                              (firstName.isNotEmpty || lastName.isNotEmpty)
                                  ? '$firstName $lastName'.trim()
                                  : null;
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
                                      if (displayName != null)
                                        Text(displayName,
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13)),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.people_outline,
                                              size: 13,
                                              color: mutualCount > 0
                                                  ? primaryColor
                                                  : Colors.grey[400]),
                                          const SizedBox(width: 4),
                                          Text(
                                            mutualCount > 0
                                                ? '$mutualCount mutual friend${mutualCount > 1 ? 's' : ''}'
                                                : 'Suggested for you',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: mutualCount > 0
                                                  ? primaryColor
                                                  : Colors.grey[500],
                                              fontWeight: mutualCount > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
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
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/chat-list'),
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
            onPressed: _loadSuggestions,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
