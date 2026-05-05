# Flutter API Integration Guide

Complete implementation guide for all 14 API endpoints from AUTH_API_ENDPOINTS.md.

## Overview

All API endpoints have been fully implemented in the Flutter app with proper models, providers, and error handling. The implementation follows these key patterns:

- **Type-safe models**: `User`, `ChatRoom`, `AuthResponse`, `UserSearchResult`
- **State management**: `AuthProvider` for auth, `RoomProvider` for rooms/members
- **Error handling**: All endpoints have try-catch with error messages
- **Logging**: Status indicators (✓, ✗) for debugging
- **Token management**: Automatic JWT handling via `TokenManager`

## Project Structure

```
flutter/lib/
├── services/
│   ├── api_service.dart          # All 14 API endpoints
│   ├── token_manager.dart         # JWT token management
│   ├── chat_service.dart          # WebSocket communication
│   └── websocket_service.dart
├── models/
│   ├── user.dart                  # User, AuthResponse, UserSearchResult
│   ├── chat_room.dart             # ChatRoom, RoomsListResponse, OperationResponse
│   └── chat_message.dart
├── providers/
│   ├── auth_provider.dart         # User authentication state
│   ├── room_provider.dart         # Room and member management state
│   └── chat_provider.dart         # Chat messages state
└── screens/
    ├── auth_screen.dart
    ├── chat_list_screen.dart
    ├── chat_screen.dart
    └── ...
```

## Models

### User Model

```dart
class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final bool isOnline;
  final DateTime? lastSeen;
  
  // Methods: fromJson(), toJson(), copyWith()
}
```

### ChatRoom Model

```dart
class ChatRoom {
  final String id;
  final String name;
  final String description;
  final String roomType; // 'GROUP' or 'DIRECT'
  final int creatorId;
  final String creatorUsername;
  final List<dynamic> participants;
  final int participantsCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Methods: fromJson(), toJson(), copyWith()
}
```

### AuthResponse Model

```dart
class AuthResponse {
  final String message;
  final User user;
  final String accessToken;
  final String refreshToken;
  
  // Methods: fromJson()
}
```

### UserSearchResult Model

```dart
class UserSearchResult {
  final List<User> results;
  final int count;
  
  // Methods: fromJson()
}
```

## API Service Methods (14 Endpoints)

### 1. Register

```dart
Future<AuthResponse> register({
  required String username,
  required String email,
  required String password,
  String? firstName,
  String? lastName,
})
```

**Example:**
```dart
final authResponse = await apiService.register(
  username: 'john_doe',
  email: 'john@example.com',
  password: 'securepass123',
  firstName: 'John',
  lastName: 'Doe',
);
final user = authResponse.user;
final accessToken = authResponse.accessToken;
```

### 2. Login

```dart
Future<AuthResponse> login({
  required String username,
  required String password,
})
```

**Example:**
```dart
final authResponse = await apiService.login(
  username: 'john_doe',
  password: 'securepass123',
);
final user = authResponse.user;
print('Logged in as: ${user.username}');
```

### 3. Refresh Access Token

```dart
Future<Map<String, dynamic>> refreshAccessToken()
```

**Example:**
```dart
final response = await apiService.refreshAccessToken();
final newAccessToken = response['access'];
```

**Note:** Token Manager automatically refreshes tokens 5 minutes before expiry, so manual calls are rarely needed.

### 4. Logout

```dart
Future<void> logout()
```

**Example:**
```dart
await apiService.logout();
// Tokens are cleared and user is logged out
```

### 5. Change Password

```dart
Future<Map<String, dynamic>> changePassword({
  required String oldPassword,
  required String newPassword,
  required String newPasswordConfirm,
})
```

**Example:**
```dart
await apiService.changePassword(
  oldPassword: 'oldpass123',
  newPassword: 'newpass456',
  newPasswordConfirm: 'newpass456',
);
```

### 6. Get Current User

```dart
Future<User> getCurrentUser()
```

**Example:**
```dart
final user = await apiService.getCurrentUser();
print('${user.username} - ${user.email}');
print('Online: ${user.isOnline}');
```

### 7. Delete User Account

```dart
Future<Map<String, dynamic>> deleteUserAccount()
```

**Warning:** This operation is irreversible!

**Example:**
```dart
// Show confirmation dialog first
final confirmed = await showDeleteAccountDialog(context);
if (confirmed) {
  await apiService.deleteUserAccount();
  // User is logged out and data is cleared
}
```

### 8. Search Users

```dart
Future<UserSearchResult> searchUsers({
  required String query,
})
```

**Constraints:**
- Query must be at least 1 character
- Returns top 5 matches

**Example:**
```dart
final result = await apiService.searchUsers(query: 'john');
print('Found ${result.count} user(s)');
for (var user in result.results) {
  print('${user.username} - ${user.email}');
}
```

### 9. List Rooms

```dart
Future<RoomsListResponse> listRooms()
```

**Example:**
```dart
final roomsResponse = await apiService.listRooms();
final rooms = roomsResponse.results;
print('You are in ${rooms.length} room(s)');
for (var room in rooms) {
  print('${room.name} (${room.roomType}) - ${room.participantsCount} members');
}
```

### 10. Create Room

```dart
Future<Map<String, dynamic>> createRoom({
  required String name,
  required String roomType,
  String? description,
  List<int>? participantIds,
})
```

**Parameters:**
- `roomType`: 'GROUP' or 'DIRECT'
- `participantIds`: Optional list of user IDs to add initially

**Example:**
```dart
final response = await apiService.createRoom(
  name: 'Project Alpha',
  roomType: 'GROUP',
  description: 'Main project discussion',
  participantIds: [2, 3, 4],
);
final roomId = response['room']['id'];
print('Created room: ${response['message']}');
```

### 11. Get Room Details

```dart
Future<ChatRoom> getRoomDetails({
  required String roomId,
})
```

**Example:**
```dart
final room = await apiService.getRoomDetails(
  roomId: '550e8400-e29b-41d4-a716-446655440000',
);
print('Room: ${room.name}');
print('Members: ${room.participantsCount}');
print('Created by: ${room.creatorUsername}');
```

### 12. Delete Room

```dart
Future<Map<String, dynamic>> deleteRoom({
  required String roomId,
})
```

**Permissions:** Only room creator can delete

**Example:**
```dart
await apiService.deleteRoom(
  roomId: '550e8400-e29b-41d4-a716-446655440000',
);
print('Room deleted');
```

### 13. Add Room Member

```dart
Future<Map<String, dynamic>> addRoomMember({
  required String roomId,
  required int userId,
})
```

**Permissions:** Only room creator can add members (for GROUP rooms)

**Example:**
```dart
await apiService.addRoomMember(
  roomId: '550e8400-e29b-41d4-a716-446655440000',
  userId: 5,
);
print('Member added');
```

### 14. Remove Room Member

```dart
Future<Map<String, dynamic>> removeRoomMember({
  required String roomId,
  required int userId,
})
```

**Alternative:** Use `leaveRoom()` to remove current user

**Permissions:** Only room creator can remove members (for GROUP rooms)

**Example - Remove another member:**
```dart
await apiService.removeRoomMember(
  roomId: '550e8400-e29b-41d4-a716-446655440000',
  userId: 5,
);
print('Member removed');
```

**Example - Leave room:**
```dart
await apiService.leaveRoom(
  roomId: '550e8400-e29b-41d4-a716-446655440000',
);
print('Left room');
```

## State Management with Providers

### AuthProvider

Manages user authentication and profile state.

```dart
final authProvider = Provider<AuthProvider>(
  (ref) => AuthProvider(apiService: apiService),
);
```

**Usage Example:**

```dart
// In a Widget
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticating) {
          return CircularProgressIndicator();
        }

        if (authProvider.isAuthenticated) {
          return Text('Welcome, ${authProvider.currentUser?.username}');
        }

        return ElevatedButton(
          onPressed: () async {
            final success = await authProvider.login(
              username: 'john_doe',
              password: 'securepass123',
            );
            if (success) {
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(authProvider.error ?? 'Login failed')),
              );
            }
          },
          child: Text('Login'),
        );
      },
    );
  }
}
```

**Methods:**
- `initialize()` - Restore session on app startup
- `register()` - Register new user
- `login()` - Login user
- `logout()` - Logout user
- `changePassword()` - Change user password
- `deleteAccount()` - Delete user account
- `refreshUserData()` - Fetch latest user info

**Getters:**
- `currentUser` - Current User object
- `isAuthenticated` - Is logged in?
- `isAuthenticating` - Operation in progress?
- `isLoading` - Data loading?
- `error` - Last error message

### RoomProvider

Manages rooms, members, and user search.

```dart
final roomProvider = Provider<RoomProvider>(
  (ref) => RoomProvider(apiService: apiService),
);
```

**Usage Example:**

```dart
class RoomsListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, child) {
        if (roomProvider.isLoading) {
          return CircularProgressIndicator();
        }

        if (roomProvider.rooms.isEmpty) {
          return Text('No rooms yet. Create one to get started!');
        }

        return ListView.builder(
          itemCount: roomProvider.rooms.length,
          itemBuilder: (context, index) {
            final room = roomProvider.rooms[index];
            return ListTile(
              title: Text(room.name),
              subtitle: Text('${room.participantsCount} members'),
              onTap: () => roomProvider.selectRoom(room.id),
            );
          },
        );
      },
    );
  }
}
```

**Methods:**
- `loadRooms()` - Fetch all rooms
- `createRoom()` - Create new room
- `selectRoom()` - Load room details
- `deleteRoom()` - Delete room
- `addRoomMember()` - Add member to room
- `removeRoomMember()` - Remove member from room
- `leaveRoom()` - Leave a room
- `searchUsers()` - Search users by username
- `clearSearch()` - Clear search results
- `clearSelectedRoom()` - Deselect room

**Getters:**
- `rooms` - List of ChatRoom objects
- `selectedRoom` - Currently selected ChatRoom
- `isLoading` - Operation in progress?
- `error` - Last error message
- `searchResults` - List of User objects from search

## Complete Login/Signup Flow

### 1. Initialize Auth on App Startup

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  final authProvider = AuthProvider(apiService: apiService);
  
  // Restore session if available
  await authProvider.initialize();
  
  runApp(MyApp(authProvider: authProvider));
}
```

### 2. Signup Screen Example

```dart
class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          appBar: AppBar(title: Text('Sign Up')),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: _firstNameController,
                  decoration: InputDecoration(labelText: 'First Name (optional)'),
                ),
                TextField(
                  controller: _lastNameController,
                  decoration: InputDecoration(labelText: 'Last Name (optional)'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: authProvider.isAuthenticating
                      ? null
                      : () async {
                          final success = await authProvider.register(
                            username: _usernameController.text,
                            email: _emailController.text,
                            password: _passwordController.text,
                            firstName: _firstNameController.text,
                            lastName: _lastNameController.text,
                          );
                          if (success) {
                            Navigator.pushReplacementNamed(context, '/home');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authProvider.error ?? 'Signup failed'),
                              ),
                            );
                          }
                        },
                  child: authProvider.isAuthenticating
                      ? CircularProgressIndicator()
                      : Text('Sign Up'),
                ),
                if (authProvider.error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      authProvider.error!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
```

### 3. Login Screen Example

```dart
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          appBar: AppBar(title: Text('Login')),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: authProvider.isAuthenticating
                      ? null
                      : () async {
                          final success = await authProvider.login(
                            username: _usernameController.text,
                            password: _passwordController.text,
                          );
                          if (success) {
                            Navigator.pushReplacementNamed(context, '/home');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authProvider.error ?? 'Login failed'),
                              ),
                            );
                          }
                        },
                  child: authProvider.isAuthenticating
                      ? CircularProgressIndicator()
                      : Text('Login'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/signup'),
                  child: Text('Don\'t have an account? Sign up'),
                ),
                if (authProvider.error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      authProvider.error!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

## Room Management Examples

### Create a Group Room

```dart
// In RoomsListScreen or a dedicated CreateRoomScreen
final success = await roomProvider.createRoom(
  name: 'Project Team',
  roomType: 'GROUP',
  description: 'Discussion for project team',
  participantIds: [2, 3, 4], // User IDs to add
);

if (success) {
  // Room created successfully
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Room created')),
  );
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(roomProvider.error ?? 'Failed to create room')),
  );
}
```

### Search Users to Add to Room

```dart
class AddMembersDialog extends StatefulWidget {
  final String roomId;

  const AddMembersDialog({required this.roomId});

  @override
  _AddMembersDialogState createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<AddMembersDialog> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, child) {
        return AlertDialog(
          title: Text('Add Members'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search users',
                  hintText: 'Type username...',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      roomProvider.clearSearch();
                    },
                  ),
                ),
                onChanged: (query) {
                  if (query.isNotEmpty) {
                    roomProvider.searchUsers(query);
                  } else {
                    roomProvider.clearSearch();
                  }
                },
              ),
              SizedBox(height: 10),
              if (roomProvider.isLoading)
                CircularProgressIndicator()
              else if (roomProvider.searchResults.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('No users found'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: roomProvider.searchResults.length,
                    itemBuilder: (context, index) {
                      final user = roomProvider.searchResults[index];
                      return ListTile(
                        title: Text(user.username),
                        subtitle: Text(user.email),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await roomProvider.addRoomMember(
                              widget.roomId,
                              user.id,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: Text('Add'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
```

### View Room Members

```dart
class RoomMembersScreen extends StatelessWidget {
  final String roomId;

  const RoomMembersScreen({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, child) {
        return Scaffold(
          appBar: AppBar(title: Text('Room Members')),
          body: roomProvider.selectedRoom == null
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: roomProvider.selectedRoom!.participants.length,
                  itemBuilder: (context, index) {
                    final participant =
                        roomProvider.selectedRoom!.participants[index];
                    return ListTile(
                      title: Text(participant['username'] ?? 'Unknown'),
                      subtitle: Text(participant['email'] ?? ''),
                      trailing: IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () async {
                          await roomProvider.removeRoomMember(
                            roomId,
                            participant['id'] as int,
                          );
                        },
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AddMembersDialog(roomId: roomId),
            ),
            child: Icon(Icons.add),
          ),
        );
      },
    );
  }
}
```

## Error Handling

All API methods include comprehensive error handling and status messages:

```dart
try {
  final user = await apiService.getCurrentUser();
  print('✓ User profile fetched');
} on SocketException {
  print('✗ Network error - check internet connection');
} on TimeoutException {
  print('✗ Request timed out');
} catch (e) {
  print('✗ Error: $e');
  
  if (e.toString().contains('401')) {
    // Unauthorized - token expired or invalid
    // Call token refresh
  } else if (e.toString().contains('403')) {
    // Forbidden - no permission
  } else if (e.toString().contains('404')) {
    // Not found
  }
}
```

## Testing the Endpoints

### Manual Testing with Curl

```bash
# Register
curl -X POST http://192.168.1.65:8000/api/v1/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test_user",
    "email": "test@example.com",
    "password": "testpass123",
    "password_confirm": "testpass123"
  }'

# Login
curl -X POST http://192.168.1.65:8000/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test_user",
    "password": "testpass123"
  }'

# Get current user (replace TOKEN)
curl -X GET http://192.168.1.65:8000/api/v1/user/me/ \
  -H "Authorization: Bearer TOKEN"

# List rooms
curl -X GET http://192.168.1.65:8000/api/v1/rooms/ \
  -H "Authorization: Bearer TOKEN"

# Create room
curl -X POST http://192.168.1.65:8000/api/v1/rooms/ \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Room",
    "room_type": "GROUP",
    "description": "Test room",
    "participant_ids": [2, 3]
  }'
```

## Summary

✅ All 14 API endpoints implemented
✅ Type-safe models with JSON serialization
✅ State management with Provider pattern
✅ Automatic token refresh
✅ Comprehensive error handling
✅ Status logging with indicators (✓, ✗)
✅ Complete documentation with examples

**Next Steps:**
1. Update your screens to use AuthProvider and RoomProvider
2. Implement UI for user search and room creation
3. Add user profile screen with password change
4. Add room management screens
5. Test all endpoints with real data
