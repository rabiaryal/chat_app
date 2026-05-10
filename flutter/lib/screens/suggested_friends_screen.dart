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
  List<User> _suggestions = [];
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
      final response = await _apiService.dio.get('/api/v1/users/suggested/');
      
      // Safety check: Ensure we are dealing with a Map before accessing 'results'
      dynamic data = response.data;
      List results = [];
      
      if (data is Map) {
        results = data['results'] ?? [];
      } else if (data is List) {
        results = data;
      }

      setState(() {
        _suggestions = results.whereType<Map<String, dynamic>>()
            .map((json) => User.fromJson(json))
            .toList();
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
      await _apiService.dio.post('/api/v1/friends/request/', data: {'to_user_id': userId});
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Friend request sent!');
      }
    } catch (e) {
      setState(() => _addedUserIds.remove(userId));
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to send request');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            // FIX: Changed '/home' to '/chat-list' to match main.dart
            onPressed: () => Navigator.of(context).pushReplacementNamed('/chat-list'),
            child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestions for you',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add people to start chatting and sharing moments.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
                          final user = _suggestions[index];
                          final isAdded = _addedUserIds.contains(user.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: primaryColor.withOpacity(0.1),
                                  child: Text(user.username[0].toUpperCase(),
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (user.firstName.isNotEmpty)
                                        Text('${user.firstName} ${user.lastName}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: isAdded ? null : () => _sendRequest(user.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAdded ? Colors.grey[200] : primaryColor,
                                    foregroundColor: isAdded ? Colors.grey : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(isAdded ? 'Sent' : 'Add'),
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
                // FIX: Changed '/home' to '/chat-list' to match main.dart
                onPressed: () => Navigator.of(context).pushReplacementNamed('/chat-list'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Go to Chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          const Text('No suggestions found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Check back later for more people to connect with.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
