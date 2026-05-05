# Authentication API Endpoints

## Quick Reference Table

| No. | Method | Endpoint | Description | Auth Required |
|-----|--------|----------|-------------|---------------|
| 1 | POST | `/api/v1/auth/register/` | Register new user | No |
| 2 | POST | `/api/v1/auth/login/` | Login user | No |
| 3 | POST | `/api/v1/auth/token/refresh/` | Refresh access token | No |
| 4 | POST | `/api/v1/auth/logout/` | Logout & invalidate token | Yes |
| 5 | POST | `/api/v1/auth/change-password/` | Change password | Yes |
| 6 | GET | `/api/v1/user/me/` | Get current user info | Yes |
| 7 | DELETE | `/api/v1/user/delete/` | Delete user account | Yes |
| 8 | GET | `/api/v1/user/search/` | Search users | Yes |
| 9 | GET | `/api/v1/rooms/` | List all rooms | Yes |
| 10 | POST | `/api/v1/rooms/` | Create new room | Yes |
| 11 | GET | `/api/v1/rooms/{room_id}/` | Get room details | Yes |
| 12 | DELETE | `/api/v1/rooms/{room_id}/` | Delete room | Yes |
| 13 | POST | `/api/v1/rooms/{room_id}/members/` | Add member | Yes |
| 14 | DELETE | `/api/v1/rooms/{room_id}/members/{user_id}/` | Remove member | Yes |

---

## Overview
Complete authentication system for the chat application with JWT token-based authentication.

---

## 1. Register
**Endpoint:** `POST /api/v1/auth/register/`

**Description:** Create a new user account and receive access/refresh tokens

**Request:**
```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "securepassword123",
  "password_confirm": "securepassword123",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response (201 Created):**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe"
  },
  "access": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

---

## 2. Login
**Endpoint:** `POST /api/v1/auth/login/`

**Description:** Login with username and password to receive access/refresh tokens

**Request:**
```json
{
  "username": "john_doe",
  "password": "securepassword123"
}
```

**Response (200 OK):**
```json
{
  "message": "Login successful",
  "user": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe"
  },
  "access": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Error Response (401 Unauthorized):**
```json
{
  "error": "Invalid credentials"
}
```

---

## 3. Refresh Token
**Endpoint:** `POST /api/v1/auth/token/refresh/`

**Description:** Get a new access token using a valid refresh token

**Request:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Response (200 OK):**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

---

## 4. Logout
**Endpoint:** `POST /api/v1/auth/logout/`

**Description:** Invalidate the refresh token (requires authentication)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Response (200 OK):**
```json
{
  "message": "Logout successful"
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "Refresh token is required"
}
```

---

## 5. Change Password
**Endpoint:** `POST /api/v1/auth/change-password/`

**Description:** Change user password (requires authentication)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request:**
```json
{
  "old_password": "oldpassword123",
  "new_password": "newpassword123",
  "new_password_confirm": "newpassword123"
}
```

**Response (200 OK):**
```json
{
  "message": "Password changed successfully"
}
```

**Error Responses:**
```json
// Missing fields
{"error": "All fields are required"}

// Incorrect old password
{"error": "Old password is incorrect"}

// Passwords don't match
{"error": "New passwords do not match"}

// Password too short
{"error": "Password must be at least 8 characters"}
```

---

## 6. Get Current User (Me)
**Endpoint:** `GET /api/v1/user/me/`

**Description:** Get current user profile information (requires authentication)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "id": 1,
  "username": "john_doe",
  "email": "john@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "is_online": true,
  "last_seen": "2026-05-02T10:30:00Z"
}
```

---

## 7. Delete User Account
**Endpoint:** `DELETE /api/v1/user/delete/`

**Description:** Delete user account and all associated data (requires authentication)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "message": "User account \"john_doe\" has been deleted successfully",
  "user": "john_doe"
}
```

**Note:** This operation is irreversible and will delete:
- User account
- All messages sent by the user
- Chat rooms created by the user
- All user profile data

---

## 8. Search Users
**Endpoint:** `GET /api/v1/user/search/`

**Description:** Search for users by username (returns top 5 matches)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `search` or `q`: Username to search for (minimum 1 character)

**Request Examples:**
```
GET /api/v1/user/search/?search=john
GET /api/v1/user/search/?q=jane
```

**Response (200 OK):**
```json
{
  "results": [
    {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "is_online": true
    },
    {
      "id": 2,
      "username": "johnny_smith",
      "email": "johnny@example.com",
      "first_name": "Johnny",
      "last_name": "Smith",
      "is_online": false
    }
  ],
  "count": 2
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "Please provide a search query (min 1 character)"
}
```

**No Results Response (200 OK):**
```json
{
  "results": [],
  "count": 0
}
```

---

## ROOMS ENDPOINTS

## 9. List All Rooms
**Endpoint:** `GET /api/v1/rooms/`

**Description:** Get all chat rooms the current user is in

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "results": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Project Alpha",
      "description": "Main project discussion room",
      "room_type": "GROUP",
      "creator_id": 1,
      "creator_username": "john_doe",
      "participants_count": 5,
      "is_active": true,
      "created_at": "2026-05-01T10:00:00Z",
      "updated_at": "2026-05-02T15:30:00Z"
    }
  ],
  "count": 1
}
```

---

## 10. Create a New Room
**Endpoint:** `POST /api/v1/rooms/`

**Description:** Create a new direct message or group chat room

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request:**
```json
{
  "name": "Project Alpha",
  "room_type": "GROUP",
  "description": "Main project discussion room",
  "participant_ids": [2, 3, 4]
}
```

**Response (201 Created):**
```json
{
  "message": "Room created successfully",
  "room": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Project Alpha",
    "description": "Main project discussion room",
    "room_type": "GROUP",
    "creator_id": 1,
    "participants_count": 4
  }
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "Room name is required"
}
```

---

## 11. Get Room Details and Members
**Endpoint:** `GET /api/v1/rooms/{room_id}/`

**Description:** Get room details and member list

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Project Alpha",
  "description": "Main project discussion room",
  "room_type": "GROUP",
  "creator_id": 1,
  "creator_username": "john_doe",
  "participants": [
    {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "is_online": true
    },
    {
      "id": 2,
      "username": "jane_smith",
      "email": "jane@example.com",
      "first_name": "Jane",
      "last_name": "Smith",
      "is_online": false
    }
  ],
  "participants_count": 2,
  "is_active": true,
  "created_at": "2026-05-01T10:00:00Z",
  "updated_at": "2026-05-02T15:30:00Z"
}
```

**Error Response (404 Not Found):**
```json
{
  "error": "Room not found"
}
```

---

## 12. Delete Room
**Endpoint:** `DELETE /api/v1/rooms/{room_id}/`

**Description:** Delete a room (creator/admin only)

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "message": "Room \"Project Alpha\" deleted successfully"
}
```

**Error Response (403 Forbidden):**
```json
{
  "error": "Only room creator can delete the room"
}
```

---

## 13. Add Member to Room
**Endpoint:** `POST /api/v1/rooms/{room_id}/members/`

**Description:** Add a member to a group room (creator only)

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request:**
```json
{
  "user_id": 5
}
```

**Response (200 OK):**
```json
{
  "message": "User \"alice_wonder\" added to room",
  "user": {
    "id": 5,
    "username": "alice_wonder"
  }
}
```

**Error Responses:**
```json
// User already in room
{"error": "User is already a member of this room"}

// User not found
{"error": "User not found"}

// Not creator (for groups)
{"error": "Only group creator can add members"}
```

---

## 14. Remove Member from Room
**Endpoint:** `DELETE /api/v1/rooms/{room_id}/members/{user_id}/`

**Description:** Remove a member from the room

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "message": "User \"alice_wonder\" removed from room",
  "user": {
    "id": 5,
    "username": "alice_wonder"
  }
}
```

**Alternative - Leave Room:**
**Endpoint:** `DELETE /api/v1/rooms/{room_id}/members/`

**Description:** Leave the room (remove current user)

```json
{
  "message": "User \"jane_smith\" removed from room",
  "user": {
    "id": 2,
    "username": "jane_smith"
  }
}
```

**Error Response (403 Forbidden):**
```json
{
  "error": "Only group creator can remove members"
}
```

**Access Token:**
- Lifetime: 24 hours (configurable)
- Used for authenticating API requests
- Include in Authorization header: `Bearer <access_token>`

**Refresh Token:**
- Lifetime: 7 days
- Used to get a new access token
- Can be invalidated on logout

---

## Authentication Header Format

For all endpoints requiring authentication:

```
Authorization: Bearer <access_token>
```

Example:
```bash
curl -X GET http://192.168.1.65:8000/api/v1/users/me/ \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
```

---

## Error Codes

| Code | Description |
|------|-------------|
| 201 | Created (successful registration) |
| 200 | OK (successful login, logout, password change) |
| 400 | Bad Request (missing/invalid fields) |
| 401 | Unauthorized (invalid credentials, authentication required) |
| 404 | Not Found |

---

## Usage Example (Flutter)

```dart
// Register
final response = await http.post(
  Uri.parse('http://192.168.1.65:8000/api/v1/auth/register/'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'username': 'john_doe',
    'email': 'john@example.com',
    'password': 'securepassword123',
    'password_confirm': 'securepassword123',
  }),
);

final data = jsonDecode(response.body);
final accessToken = data['access'];
final refreshToken = data['refresh'];

// Login
final response = await http.post(
  Uri.parse('http://192.168.1.65:8000/api/v1/auth/login/'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'username': 'john_doe',
    'password': 'securepassword123',
  }),
);

// Use with authenticated request
final response = await http.get(
  Uri.parse('http://192.168.1.65:8000/api/v1/users/me/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

// Refresh token
final response = await http.post(
  Uri.parse('http://192.168.1.65:8000/api/v1/auth/token/refresh/'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'refresh': refreshToken}),
);

// Logout
final response = await http.post(
  Uri.parse('http://192.168.1.65:8000/api/v1/auth/logout/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'refresh': refreshToken}),
);

// Change password
final response = await http.post(
  Uri.parse('http://192.168.1.65:8000/api/v1/auth/change-password/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'old_password': 'oldpassword123',
    'new_password': 'newpassword123',
    'new_password_confirm': 'newpassword123',
  }),
);

// Get current user info
final response = await http.get(
  Uri.parse('http://192.168.1.65:8000/api/v1/user/me/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

final userData = jsonDecode(response.body);
print('Username: ${userData['username']}');
print('Email: ${userData['email']}');

// Search users
final response = await http.get(
  Uri.parse('http://192.168.1.65:8000/api/v1/user/search/?search=john'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

final searchResults = jsonDecode(response.body);
List<dynamic> users = searchResults['results'];
int count = searchResults['count'];

// Delete user account
final response = await http.delete(
  Uri.parse('http://192.168.1.65:8000/api/v1/user/delete/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

// List all rooms
final response = await http.get(
  Uri.parse('http://192.168.1.65:8000/api/v1/rooms/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

final roomsData = jsonDecode(response.body);
List<dynamic> rooms = roomsData['results'];

// Create a new room
final response = await http.post(
  Uri.parse('http://192.168.1.65:8000/api/v1/rooms/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'name': 'Project Alpha',
    'room_type': 'GROUP',
    'description': 'Main project discussion',
    'participant_ids': [2, 3, 4],
  }),
);

// Get room details
final response = await http.get(
  Uri.parse('http://192.168.1.65:8000/api/v1/rooms/550e8400-e29b-41d4-a716-446655440000/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

final roomData = jsonDecode(response.body);
List<dynamic> members = roomData['participants'];

// Add member to room
final response = await http.post(
  Uri.parse('http://192.168.1.65:8000/api/v1/rooms/550e8400-e29b-41d4-a716-446655440000/members/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'user_id': 5}),
);

// Remove member from room
final response = await http.delete(
  Uri.parse('http://192.168.1.65:8000/api/v1/rooms/550e8400-e29b-41d4-a716-446655440000/members/5/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

// Leave room (remove current user)
final response = await http.delete(
  Uri.parse('http://192.168.1.65:8000/api/v1/rooms/550e8400-e29b-41d4-a716-446655440000/members/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);

// Delete room (creator only)
final response = await http.delete(
  Uri.parse('http://192.168.1.65:8000/api/v1/rooms/550e8400-e29b-41d4-a716-446655440000/'),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);
```
