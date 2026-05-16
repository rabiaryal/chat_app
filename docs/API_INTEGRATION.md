# API Integration Architecture

## Overview

The Flutter app uses a **centralized, standardized API endpoint management system** that ensures all API calls go through a single source of truth. This document explains:

1. **The Error We Fixed** and why it happened
2. **How BaseURL Integration Works** 
3. **The Complete Request Flow**
4. **Best Practices** for using the API system

---

## 1. The Error We Fixed

### Problem
```dart
// ❌ WRONG - Type Mismatch
Future<Map<String, dynamic>> sendMessage({
    required int roomId,        // <-- Parameter is int
    required String content,
    String? mediaUrl,
  }) async {
    try {
      final response = await dio.post(
        ApiConstant.sendMessage(roomId),  // <-- ApiConstant expects String!
```

### Root Cause
- Function parameter: `roomId` is an `int`
- `ApiConstant.sendMessage()` method signature: expects a `String`
- **Dart is type-safe**, so passing `int` to a function expecting `String` causes a compile error

### Solution
```dart
// ✅ CORRECT - Convert to String
final response = await dio.post(
  ApiConstant.sendMessage(roomId.toString()),  // Convert int to String
```

### Why This Inconsistency?
Different endpoints have different ID types in the backend:
- **Room IDs**: Strings (UUIDs in Django) → functions take `String`
- **User/Message IDs**: Integers → must convert to `String` when building URLs

---

## 2. How BaseURL Integration Works

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ApiConstant                              │
│                                                              │
│  static const String baseUrl =                              │
│    'https://chat.rabiaryal.com.np'                          │
│                                                              │
│  static String sendMessage(String roomId) =>                │
│    '$apiVersion/rooms/$roomId/messages/'                    │
│    // Result: '/api/v1/rooms/{roomId}/messages/'            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                   ApiService                                │
│                                                              │
│  ApiService({                                               │
│    this.baseUrl = 'https://chat.rabiaryal.com.np',          │
│    HiveTokenStorage? tokenStorage,                          │
│  }) : tokenStorage = ... {                                  │
│    _dioClient = DioClient(                                  │
│      tokenStorage: this.tokenStorage,                       │
│      baseUrl: baseUrl,   // <-- PASS baseUrl HERE           │
│    );                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                   DioClient                                 │
│                                                              │
│  DioClient({                                                │
│    required this.tokenStorage,                              │
│    required this.baseUrl,                                   │
│  }) {                                                       │
│    dio = Dio(BaseOptions(                                   │
│      baseUrl: baseUrl,  // <-- Configured in Dio            │
│      connectTimeout: Duration(seconds: 30),                 │
│      receiveTimeout: Duration(seconds: 30),                 │
│      ...                                                     │
│    ));                                                       │
│    dio.interceptors.add(AuthInterceptor(...));              │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│              HTTP Request (Dio)                             │
│                                                              │
│  dio.post('/api/v1/rooms/{roomId}/messages/', data: {...})  │
│                                                              │
│  Dio combines:                                              │
│    baseUrl: 'https://chat.rabiaryal.com.np'                 │
│    + endpoint: '/api/v1/rooms/{roomId}/messages/'           │
│    = FINAL URL: 'https://chat.rabiaryal.com.np/api/v1/...   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│           AuthInterceptor (Before Request)                  │
│                                                              │
│  1. Skip token for /auth/login/, /auth/register/            │
│  2. Add Authorization header for all other routes:          │
│     'Authorization': 'Bearer {accessToken}'                 │
│  3. Add Content-Type: 'application/json'                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│            Django Backend                                   │
│         /api/v1/rooms/{roomId}/messages/                    │
│                                                              │
│  Backend receives complete request:                         │
│  ✓ Full URL (constructed by Dio)                            │
│  ✓ Authorization token (injected by AuthInterceptor)        │
│  ✓ Request body (user data)                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Complete Request Flow: Step by Step

### Example: Sending a Message

```dart
// Step 1: User calls sendMessage
await apiService.sendMessage(
  roomId: 123,
  content: "Hello!",
);
```

### What Happens Behind the Scenes:

#### Step 1: ApiService.sendMessage()
```dart
Future<Map<String, dynamic>> sendMessage({
  required int roomId,
  required String content,
  String? mediaUrl,
}) async {
  try {
    final response = await dio.post(
      ApiConstant.sendMessage(roomId.toString()),  // Convert to String
      data: {
        'content': content,
        if (mediaUrl != null) 'media_url': mediaUrl,
      },
    );
```

#### Step 2: ApiConstant.sendMessage() Returns Path
```dart
static String sendMessage(String roomId) =>
    '$apiVersion/rooms/$roomId/messages/';
    // Returns: '/api/v1/rooms/123/messages/'
```

#### Step 3: Dio.post() Combines BaseURL + Path
```
Internal Dio Logic:
- baseUrl: 'https://chat.rabiaryal.com.np'
- endpoint: '/api/v1/rooms/123/messages/'
- Final URL: 'https://chat.rabiaryal.com.np/api/v1/rooms/123/messages/'
```

#### Step 4: AuthInterceptor Adds Token
```dart
// AuthInterceptor.onRequest() automatically:
final accessToken = tokenStorage.getAccessToken();
options.headers['Authorization'] = 'Bearer $accessToken';
options.headers['Content-Type'] = 'application/json';
```

#### Step 5: HTTP Request is Sent
```
POST https://chat.rabiaryal.com.np/api/v1/rooms/123/messages/
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "content": "Hello!"
}
```

#### Step 6: Django Backend Processes Request
```python
# Django Route: /api/v1/rooms/<roomId>/messages/
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def room_messages_create(request, roomId):
    # JWT token is validated by DRF
    # Request body is parsed
    # Message is created
    return Response(message_data, status=201)
```

#### Step 7: Response is Returned
```dart
if (response.statusCode == 201) {
  print('✓ Message sent to room $roomId');
  return response.data;  // { id, content, timestamp, ... }
} else {
  throw Exception('Failed to send message');
}
```

---

## 4. BaseURL Configuration Locations

### Why We Don't Hardcode BaseURL in Every Endpoint

**❌ BAD APPROACH** (Hardcoded):
```dart
// api_service.dart
await dio.post('https://chat.rabiaryal.com.np/api/v1/auth/login/', ...);
await dio.post('https://chat.rabiaryal.com.np/api/v1/user/me/', ...);
await dio.post('https://chat.rabiaryal.com.np/api/v1/rooms/', ...);
// ❌ Repeated 50+ times across the codebase!
// ❌ If domain changes, must update 50+ locations!
```

**✅ GOOD APPROACH** (Centralized):
```dart
// ApiConstant.dart
class ApiConstant {
  static const String baseUrl = 'https://chat.rabiaryal.com.np';
  // ✓ Single location to change domain
  // ✓ Dio's BaseOptions handles combining it with endpoints
}

// ApiService.dart
ApiService({
  this.baseUrl = 'https://chat.rabiaryal.com.np',  // Can override in tests
  HiveTokenStorage? tokenStorage,
}) : tokenStorage = tokenStorage ?? HiveTokenStorage() {
  _dioClient = DioClient(
    tokenStorage: this.tokenStorage,
    baseUrl: baseUrl,  // ✓ Pass to DioClient
  );
}

// DioClient.dart
DioClient({
  required this.tokenStorage,
  required this.baseUrl,
}) {
  dio = Dio(BaseOptions(
    baseUrl: baseUrl,  // ✓ Dio uses this for all requests
    ...
  ));
}
```

---

## 5. Complete Request Lifecycle with Error Handling

```
User Action
    ↓
    ├─→ apiService.sendMessage(roomId: 123, content: "Hi")
    │
    ├─→ ApiConstant.sendMessage("123") returns "/api/v1/rooms/123/messages/"
    │
    ├─→ dio.post("/api/v1/rooms/123/messages/", data: {...})
    │
    ├─→ AuthInterceptor.onRequest()
    │   ├─→ Get access token from Hive
    │   ├─→ Add "Authorization: Bearer {token}" header
    │   └─→ Continue request
    │
    ├─→ HTTP Request sent:
    │   POST https://chat.rabiaryal.com.np/api/v1/rooms/123/messages/
    │
    ├─→ Django receives request
    │   ├─→ Validates JWT token
    │   ├─→ Checks user is room member
    │   ├─→ Creates message
    │   └─→ Returns 201 + message data
    │
    ├─→ DioClient receives response
    │   ├─→ Check statusCode == 201?
    │   ├─→ If YES: return response.data
    │   └─→ If NO: throw DioException
    │
    ├─→ AuthInterceptor.onError()
    │   ├─→ Check if statusCode == 401?
    │   ├─→ If YES: attempt token refresh
    │   │   ├─→ Call /api/v1/auth/token/refresh/
    │   │   ├─→ Save new access token
    │   │   └─→ Retry original request
    │   └─→ If NO: pass error to caller
    │
    └─→ Back to caller (ApiService.sendMessage)
        ├─→ if (response.statusCode == 201) { return response.data; }
        └─→ else { throw Exception(...); }
```

---

## 6. Environment-Specific Configuration

### Development (Local)
```dart
// Override baseUrl in main.dart
final apiService = ApiService(
  baseUrl: 'http://localhost:8000',
);
```

### Production (Current)
```dart
// Use default from ApiConstant
final apiService = ApiService(
  baseUrl: 'https://chat.rabiaryal.com.np',
);
```

### Testing
```dart
// Use mock baseUrl
final apiService = ApiService(
  baseUrl: 'http://127.0.0.1:8001',
);
```

---

## 7. Files Involved in BaseURL Integration

```
📁 flutter/lib/
│
├─ constants/
│  └─ api_constant.dart          ← Define baseUrl + all endpoints
│
├─ services/
│  ├─ api_service.dart           ← Accept baseUrl, pass to DioClient
│  ├─ dio_client.dart            ← Configure Dio with baseUrl
│  ├─ hive_token_storage.dart    ← Store/retrieve tokens (used by interceptor)
│  ├─ token_manager.dart         ← Manage token lifecycle
│  └─ chat_repository.dart       ← Use apiService for API calls
│
├─ providers/
│  └─ room_provider.dart         ← Use ApiConstant for endpoints
│
└─ main.dart                      ← Initialize ApiService
```

### Request Flow Through Files:

```
main.dart
  ↓ creates
ApiService (with baseUrl)
  ↓ creates
DioClient (with baseUrl)
  ↓ sets up
Dio (with BaseOptions.baseUrl)
  ↓ adds
AuthInterceptor (injects token)
  ↓ makes request with
ApiConstant endpoints (relative paths)
  ↓ combines into
Full URL: baseUrl + endpoint
  ↓ sends to
Django Backend
```

---

## 8. Common Patterns & Best Practices

### ✅ Correct Usage Patterns

**Pattern 1: String RoomId (UUID)**
```dart
Future<void> leaveRoom(String roomId) async {
  final response = await dio.delete(
    ApiConstant.leaveRoom(roomId)  // roomId is already String
  );
}
```

**Pattern 2: Integer IDs (Convert to String)**
```dart
Future<Map<String, dynamic>> sendMessage({
  required int roomId,
  required String content,
}) async {
  final response = await dio.post(
    ApiConstant.sendMessage(roomId.toString()),  // ← Convert int to String
    data: { 'content': content }
  );
}
```

**Pattern 3: Multiple IDs**
```dart
Future<Map<String, dynamic>> removeRoomMember({
  required String roomId,      // UUID - keep as String
  required int userId,         // Integer ID - convert to String
}) async {
  final response = await dio.delete(
    ApiConstant.removeRoomMember(roomId, userId.toString())
  );
}
```

### ❌ Anti-Patterns (Avoid!)

```dart
// ❌ Never hardcode baseUrl in requests
await dio.post('https://chat.rabiaryal.com.np/api/v1/rooms/');

// ❌ Never mix baseUrl references
await dio.post('${apiService.baseUrl}/api/v1/rooms/');  // Redundant!

// ❌ Never skip ApiConstant
await dio.post('/api/v1/rooms/$roomId/messages/');  // What if path changes?
```

---

## 9. Summary Table

| Component | Responsibility | Location |
|-----------|-----------------|----------|
| **ApiConstant** | Define baseUrl + all relative endpoints | `constants/api_constant.dart` |
| **ApiService** | Accept baseUrl, provide API methods | `services/api_service.dart` |
| **DioClient** | Configure Dio with baseUrl + interceptors | `services/dio_client.dart` |
| **AuthInterceptor** | Inject tokens + handle 401 refresh | `services/dio_client.dart` |
| **Dio (library)** | Combine baseUrl + endpoint → full URL | Package dependency |
| **Django Backend** | Receive request at full URL | Backend |

---

## 10. Troubleshooting

### Issue: "API endpoint not found" (404)
```
Check:
1. Is baseUrl correct? ApiConstant.baseUrl
2. Is endpoint path correct? ApiConstant.xyz()
3. Is full URL being constructed? baseUrl + endpoint
4. Example: https://chat.rabiaryal.com.np/api/v1/rooms/123/messages/
```

### Issue: "Unauthorized" (401)
```
Check:
1. Is AuthInterceptor adding token? Check onRequest()
2. Is token stored in Hive? Check HiveTokenStorage
3. Is token valid? Check expiration
4. AuthInterceptor will auto-refresh if expired
```

### Issue: Type mismatch (Dart error)
```
Check:
1. Is roomId an int? Must convert to String: roomId.toString()
2. Is userId an int? Must convert: userId.toString()
3. All ApiConstant methods expect String parameters for IDs
```

---

## 11. Future Improvements

1. **Environment-based baseUrl**
   ```dart
   static const String baseUrl = const String.fromEnvironment(
     'API_BASE_URL',
     defaultValue: 'https://chat.rabiaryal.com.np',
   );
   ```

2. **Centralized error handling**
   ```dart
   // Handle all 401/403/500 errors in one place
   // Instead of in each API method
   ```

3. **Request/Response logging**
   ```dart
   // Log all requests in AuthInterceptor for debugging
   print('→ ${options.method} ${options.path}');
   ```

4. **Rate limiting & retry logic**
   ```dart
   // Auto-retry failed requests with exponential backoff
   ```
