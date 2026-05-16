import 'package:chat_app/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/api_service.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Set<int> _selectedFriendIds = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Load friends if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FriendProvider>().loadFriends();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend')),
      );
      return;
    }

    setState(() => _isCreating = true);

    final apiService = context.read<ApiService>();
    final result = await apiService.createGroup(
      name: name,
      description: _descriptionController.text.trim(),
      participantIds: _selectedFriendIds.toList(),
    ).run();

    result.fold(
      (failure) {
        if (mounted) {
          setState(() => _isCreating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create group: ${failure.message}')),
          );
        }
      },
      (room) {
        if (!mounted) return;

        // Add the new group to RoomProvider
        final roomProvider = context.read<RoomProvider>();
        roomProvider.addRoom(room);

        // Navigate to the new chat screen
        final chatProvider = context.read<ChatProvider>();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: chatProvider,
              child: ChatScreen(
                roomId: room.id,
                roomName: room.name,
                userId: room.creatorId,
                username: room.name, // For groups, we use room name as username
                friendId: 0, // Not applicable for groups
                isGroup: true,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: const Text(
                'CREATE',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter group name',
                    prefixIcon: Icon(Icons.group_work),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'What is this group about?',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Select Participants',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_selectedFriendIds.length} selected',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<FriendProvider>(
              builder: (context, friendProvider, _) {
                if (friendProvider.isLoading &&
                    friendProvider.friends.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (friendProvider.friends.isEmpty) {
                  return const Center(
                    child: Text('You need friends to create a group!'),
                  );
                }

                return ListView.builder(
                  itemCount: friendProvider.friends.length,
                  itemBuilder: (context, index) {
                    final friend = friendProvider.friends[index];
                    final isSelected = _selectedFriendIds.contains(friend.id);

                    return CheckboxListTile(
                      title: Text(friend.displayName),
                      subtitle: Text('@${friend.username}'),
                      secondary: CircleAvatar(
                        child: Text(friend.username[0].toUpperCase()),
                      ),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedFriendIds.add(friend.id);
                          } else {
                            _selectedFriendIds.remove(friend.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createGroup,
                icon: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.group_add),
                label: Text(_isCreating ? 'Creating...' : 'Create Group'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
