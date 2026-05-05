import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_controller.dart';
import '../services/api_service.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

/// FriendProfile Screen
///
/// Displays a friend's profile with:
/// - Avatar and basic info
/// - "Message" button (smart state-aware)
/// - Friend request button (if not friends yet)
///
/// STATES:
/// - Not Friends Yet: "Add Friend" button
/// - Request Pending: "Request Pending" (disabled)
/// - Friends: "Message" button (enabled)
/// - Loading: Spinner overlay
class FriendProfileScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String? avatar;
  final String? bio;

  const FriendProfileScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.avatar,
    this.bio,
  }) : super(key: key);

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  late ChatController _chatController;
  FriendshipStatus _friendshipStatus = FriendshipStatus.notFriends;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chatController = ChatController(apiService: ApiService());
    _checkFriendshipStatus();
  }

  Future<void> _checkFriendshipStatus() async {
    try {
      final status = await _chatController.checkFriendshipStatus(
        targetUserId: widget.userId,
      );
      setState(() {
        _friendshipStatus = status;
      });
    } catch (e) {
      print('Error checking friendship status: $e');
    }
  }

  Future<void> _onSendFriendRequest() async {
    setState(() => _isLoading = true);
    try {
      await _chatController.sendFriendRequest(targetUserId: widget.userId);
      setState(() {
        _friendshipStatus = FriendshipStatus.pending;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${widget.username}')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _onInitializeChat() async {
    setState(() => _isLoading = true);
    try {
      final response = await _chatController.initializeChat(
        targetUserId: widget.userId,
      );

      if (!mounted) return;

      // Navigate to ChatScreen with the room
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: Provider.of<ChatProvider>(context, listen: false),
            child: ChatScreen(
              roomId: response.roomId,
              roomName: response.roomName,
              userId: 0, // Will be set from context in ChatScreen
              username: widget.username,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Handle friendship exception
      if (e is FriendshipException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot message: ${e.message}'),
            action: SnackBarAction(
              label: 'Add Friend',
              onPressed: _onSendFriendRequest,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Section
                Container(
                  width: double.infinity,
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: widget.avatar != null
                            ? NetworkImage(widget.avatar!)
                            : null,
                        child: widget.avatar == null
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey[400],
                              )
                            : null,
                      ),
                      SizedBox(height: 16),
                      Text(
                        widget.username,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),

                // Bio Section
                if (widget.bio != null)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bio',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.bio!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                // Action Button Section
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_friendshipStatus == FriendshipStatus.notFriends)
                        ElevatedButton.icon(
                          onPressed: _onSendFriendRequest,
                          icon: Icon(Icons.person_add),
                          label: Text('Add Friend'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        )
                      else if (_friendshipStatus == FriendshipStatus.pending)
                        ElevatedButton.icon(
                          onPressed: null, // Disabled
                          icon: Icon(Icons.hourglass_top),
                          label: Text('Request Pending'),
                          style: ElevatedButton.styleFrom(
                            disabledForegroundColor:
                                Colors.grey.withOpacity(0.38),
                            disabledBackgroundColor:
                                Colors.grey.withOpacity(0.12),
                          ),
                        )
                      else if (_friendshipStatus == FriendshipStatus.accepted)
                        ElevatedButton.icon(
                          onPressed: _onInitializeChat,
                          icon: Icon(Icons.message),
                          label: Text('Message'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Initializing chat...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
