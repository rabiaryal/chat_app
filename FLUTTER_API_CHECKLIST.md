# Flutter API Implementation Checklist

Quick reference for implementing API endpoints in your Flutter screens.

## Setup & Initialization

- [ ] Import new models: `user.dart`, `chat_room.dart`
- [ ] Import new providers: `auth_provider.dart`, `room_provider.dart`
- [ ] Import ApiService in providers
- [ ] Initialize AuthProvider on app startup with `initialize()`
- [ ] Set up Provider bindings in main.dart

```dart
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  final authProvider = AuthProvider(apiService: apiService);
  final roomProvider = RoomProvider(apiService: apiService);
  
  await authProvider.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => apiService),
        ChangeNotifierProvider<AuthProvider>(create: (_) => authProvider),
        ChangeNotifierProvider<RoomProvider>(create: (_) => roomProvider),
      ],
      child: MyApp(),
    ),
  );
}
```

## Auth Endpoints

### Register Screen

- [ ] Add TextField for username
- [ ] Add TextField for email
- [ ] Add TextField for password
- [ ] Add TextField for password confirm (verify client-side)
- [ ] Add TextField for first name (optional)
- [ ] Add TextField for last name (optional)
- [ ] Call `authProvider.register()`
- [ ] On success: Navigate to home/login
- [ ] Show error message on failure
- [ ] Show loading indicator while authenticating

```dart
final success = await authProvider.register(
  username: username,
  email: email,
  password: password,
  firstName: firstName,
  lastName: lastName,
);
```

### Login Screen

- [ ] Add TextField for username
- [ ] Add TextField for password
- [ ] Call `authProvider.login()`
- [ ] On success: Navigate to home
- [ ] Show error message on failure
- [ ] Add "Sign up" link
- [ ] Show loading indicator while authenticating

```dart
final success = await authProvider.login(
  username: username,
  password: password,
);
```

### Home Screen (After Login)

- [ ] Display current user info: `authProvider.currentUser`
- [ ] Add logout button: `authProvider.logout()`
- [ ] Show user status: `currentUser?.isOnline`
- [ ] Add menu/drawer with options:
  - [ ] Refresh user data: `authProvider.refreshUserData()`
  - [ ] Change password
  - [ ] Delete account
  - [ ] View profile

### Profile Screen

- [ ] Display user data: `authProvider.currentUser`
  - [ ] Username
  - [ ] Email
  - [ ] First name, last name
  - [ ] Online status
  - [ ] Last seen

### Change Password Screen

- [ ] Add TextField for old password
- [ ] Add TextField for new password
- [ ] Add TextField for new password confirm
- [ ] Validate passwords match (client-side)
- [ ] Call `authProvider.changePassword()`
- [ ] Show success/error message
- [ ] Navigate back on success

```dart
final success = await authProvider.changePassword(
  oldPassword: oldPassword,
  newPassword: newPassword,
  newPasswordConfirm: newPasswordConfirm,
);
```

### Delete Account Screen

- [ ] Show warning message
- [ ] Add confirmation checkbox
- [ ] Disable button until confirmed
- [ ] Call `authProvider.deleteAccount()`
- [ ] Navigate to login after deletion

## Room Endpoints

### Rooms List Screen

- [ ] Call `roomProvider.loadRooms()` in initState
- [ ] Display list of rooms: `roomProvider.rooms`
- [ ] Show loading indicator: `roomProvider.isLoading`
- [ ] Show error message: `roomProvider.error`
- [ ] On room tap: `roomProvider.selectRoom(roomId)`
- [ ] Add floating action button to create room
- [ ] Pull-to-refresh to reload rooms
- [ ] Display room info:
  - [ ] Room name
  - [ ] Room type (GROUP/DIRECT)
  - [ ] Participant count
  - [ ] Description

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Provider.of<RoomProvider>(context, listen: false).loadRooms();
  });
}
```

### Create Room Screen

- [ ] Add TextField for room name
- [ ] Add TextField for description (optional)
- [ ] Add dropdown for room type (GROUP/DIRECT)
- [ ] Add member selection (if GROUP):
  - [ ] Search users: `roomProvider.searchUsers(query)`
  - [ ] Display search results: `roomProvider.searchResults`
  - [ ] Select multiple users
  - [ ] Show selected users with remove button
- [ ] Call `roomProvider.createRoom()`
- [ ] Show success message
- [ ] Navigate back to rooms list
- [ ] Show error message on failure

```dart
final success = await roomProvider.createRoom(
  name: name,
  roomType: roomType,
  description: description,
  participantIds: selectedUserIds,
);
```

### Room Details Screen

- [ ] Call `roomProvider.selectRoom(roomId)` on open
- [ ] Display room info: `roomProvider.selectedRoom`
  - [ ] Room name
  - [ ] Description
  - [ ] Created by (creator username)
  - [ ] Participant count
- [ ] Show member list (if GROUP):
  - [ ] List all participants
  - [ ] Show username, email, status
  - [ ] If creator: Add remove button for each member
- [ ] Show room actions:
  - [ ] If creator: Delete room button
  - [ ] Always: Leave room button
  - [ ] If GROUP: Add member button

### Add Member to Room Dialog

- [ ] Add search field:
  - [ ] User types: trigger `roomProvider.searchUsers(query)`
  - [ ] Show loading indicator
- [ ] Display search results:
  - [ ] List users with username, email, online status
  - [ ] Each user has "Add" button
- [ ] Call `roomProvider.addRoomMember(roomId, userId)`
- [ ] On success: Close dialog and reload room details
- [ ] Show error message on failure

```dart
await roomProvider.addRoomMember(roomId, userId);
```

### Remove Member from Room

- [ ] On member list: Add remove/delete button
- [ ] Show confirmation dialog
- [ ] Call `roomProvider.removeRoomMember(roomId, userId)`
- [ ] On success: Reload room details
- [ ] Show error message on failure

### Leave Room

- [ ] Add "Leave Room" button on room details
- [ ] Show confirmation dialog
- [ ] Call `roomProvider.leaveRoom(roomId)`
- [ ] On success: Navigate back to rooms list
- [ ] Show error message on failure

### Delete Room (Creator Only)

- [ ] Add "Delete Room" button (only show if current user is creator)
- [ ] Show warning dialog
- [ ] Call `roomProvider.deleteRoom(roomId)`
- [ ] On success: Navigate back to rooms list
- [ ] Show error message on failure

## User Search (Standalone)

### User Search Screen

- [ ] Add search TextField
- [ ] On text change: Call `roomProvider.searchUsers(query)`
  - [ ] Only search if query.length >= 1
  - [ ] Show loading indicator while searching
- [ ] Display results: `roomProvider.searchResults`
  - [ ] Show username, email, online status
  - [ ] Each user has action button (Add to room, View profile, etc.)
- [ ] Clear search on button: `roomProvider.clearSearch()`

## WebSocket Integration

### Connect WebSocket After Login

```dart
// In ChatScreen or similar
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Provider.of<ChatProvider>(context, listen: false).initialize(
      roomId: widget.roomId,
      userId: authProvider.currentUser!.id,
      username: authProvider.currentUser!.username,
    );
  });
}
```

### Send Message via WebSocket

```dart
// Not via HTTP - use ChatService WebSocket
chatProvider.sendMessage(messageContent);
```

## Error Handling Strategy

- [ ] Check `isLoading` before showing content
- [ ] Display `error` message in SnackBar or AlertDialog
- [ ] Provide retry button on error
- [ ] Handle timeout errors gracefully
- [ ] Handle 401 (unauthorized) by logging out
- [ ] Handle 403 (forbidden) with permission denied message
- [ ] Handle 404 (not found) with not found message

```dart
if (authProvider.error != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(authProvider.error!),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => authProvider.login(...),
      ),
    ),
  );
}
```

## Session Management

- [ ] Call `authProvider.initialize()` on app startup
- [ ] Check `authProvider.isAuthenticated` for protected routes
- [ ] Handle token expiry with auto-refresh (TokenManager does this)
- [ ] Clear state on logout: providers already handle this
- [ ] Graceful navigation:
  - [ ] If authenticated: Show home
  - [ ] If not authenticated: Show login

```dart
@override
Widget build(BuildContext context) {
  return Consumer<AuthProvider>(
    builder: (context, authProvider, child) {
      if (authProvider.isLoading) {
        return LoadingScreen();
      }
      
      return authProvider.isAuthenticated
          ? HomeScreen()
          : LoginScreen();
    },
  );
}
```

## Testing Checklist

- [ ] Test registration with valid/invalid data
- [ ] Test login with correct/incorrect credentials
- [ ] Test token refresh (automatic)
- [ ] Test logout
- [ ] Test password change
- [ ] Test user profile fetch
- [ ] Test user search
- [ ] Test room creation (GROUP and DIRECT)
- [ ] Test room listing
- [ ] Test room details with members
- [ ] Test add member to room
- [ ] Test remove member from room
- [ ] Test delete room (creator only)
- [ ] Test leave room
- [ ] Test error handling (network error, invalid token, permission denied)
- [ ] Test session persistence (restart app, tokens still valid)
- [ ] Test WebSocket connection after login
- [ ] Test message sending via WebSocket

## API Response Status Codes

| Code | Meaning | Handling |
|------|---------|----------|
| 200 | OK | Success - use response data |
| 201 | Created | Success - room/message created |
| 400 | Bad Request | Show error message to user |
| 401 | Unauthorized | Token expired/invalid - refresh or logout |
| 403 | Forbidden | No permission - show permission denied message |
| 404 | Not Found | Room/user not found - show not found message |
| 500 | Server Error | Show "Server error, try again later" |

## Environment Configuration

Update these files for production:

- [ ] [api_service.dart](flutter/lib/services/api_service.dart)
  - [ ] Change `baseUrl` from `http://192.168.1.65:8000` to production domain
  - [ ] Add environment config (dev, staging, prod)

- [ ] [chat_service.dart](flutter/lib/services/chat_service.dart)
  - [ ] Change WebSocket URL from `ws://` to `wss://`
  - [ ] Update host from `192.168.1.65:8000` to production domain

- [ ] [token_manager.dart](flutter/lib/services/token_manager.dart)
  - [ ] Verify secure storage is working
  - [ ] Configure token refresh timing if needed

## Firebase/Analytics Integration (Optional)

- [ ] Add Firebase Analytics tracking for:
  - [ ] Login/Signup/Logout events
  - [ ] Room creation
  - [ ] Message sent
  - [ ] Errors/crashes

```dart
FirebaseAnalytics.instance.logLogin();
FirebaseAnalytics.instance.logEvent(
  name: 'room_created',
  parameters: {'room_type': 'GROUP'},
);
```

## Performance Optimization

- [ ] Implement pagination for rooms list (if many rooms)
- [ ] Implement pagination for members list (if many members)
- [ ] Cache room data locally
- [ ] Debounce search input (wait 500ms after user stops typing)
- [ ] Lazy load room details (only fetch members when viewing)
- [ ] Unsubscribe from streams in dispose()

---

**Total Endpoints Implemented:** 14/14 ✅
**Total Providers Created:** 3 (AuthProvider, RoomProvider, ChatProvider) ✅
**Total Models Created:** 4 (User, ChatRoom, AuthResponse, UserSearchResult) ✅
