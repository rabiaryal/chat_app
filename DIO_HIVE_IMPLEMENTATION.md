# Dio + Hive Token Management System

## Overview
Successfully migrated from HTTP + Flutter SecureStorage to **Dio HTTP client** with **Hive local database** for automatic token management and persistence.

## Key Features Implemented

### 1. **Hive Token Storage** (`hive_token_storage.dart`)
- **Persistent storage** using Hive database (local, encrypted)
- **Methods:**
  - `initialize()` - Initialize Hive on app startup
  - `saveTokens()` - Store access and refresh tokens
  - `getAccessToken()` / `getRefreshToken()` - Retrieve tokens
  - `clearTokens()` - Remove tokens on logout
  - `hasTokens()` - Check if tokens exist
  - `getAllTokens()` - Debug method to view all stored tokens
  - `close()` - Close Hive box on app shutdown

### 2. **Dio HTTP Client with Interceptors** (`dio_client.dart`)
- **AuthInterceptor** - Automatically adds Bearer token to all requests
- **Automatic Token Refresh** - Handles 401 responses with token refresh
- **Features:**
  - Prevents multiple simultaneous token refresh attempts with lock mechanism
  - Retries failed requests with new token automatically
  - Logs all HTTP interactions for debugging
  - Graceful fallback when token refresh fails

**How it Works:**
1. Every request automatically includes `Authorization: Bearer {accessToken}` header
2. If server returns 401 Unauthorized:
   - Interceptor uses refresh token to get new access token
   - Stores new token in Hive
   - Retries the original request with new token
3. If refresh fails (expired refresh token), clears tokens and redirects to login

### 3. **Updated Token Manager** (`token_manager.dart`)
- **Now uses HiveTokenStorage** instead of FlutterSecureStorage
- **Methods:**
  - `saveTokens()` - Saves to Hive with automatic refresh scheduling
  - `updateAccessToken()` - Updates token and reschedules refresh
  - `clearTokens()` - Logout cleanup
  - `getTokenStatus()` - Debug method for token information

### 4. **Refactored ApiService** (`api_service.dart`)
- **Uses Dio instead of http package**
- **All requests automatically include Bearer token** (via interceptor)
- **No need to manually add headers** for authenticated endpoints
- **Automatic token refresh** on 401 responses
- **All friend/message/auth endpoints work seamlessly**

### 5. **Main App Initialization** (`main.dart`)
- **Hive initialized on app startup** before creating ApiService
- **Clean shutdown** of Hive storage on app exit
- **TokenStorage passed to ApiService** for centralized management

## Migration Benefits

### Before (HTTP + SecureStorage)
```
❌ Manual header creation for every request
❌ Token refresh logic scattered across codebase
❌ No automatic retry on token expiration
❌ Manual token checking before API calls
❌ Less efficient storage for tokens
```

### After (Dio + Hive)
```
✅ Automatic Bearer token injection via interceptor
✅ Centralized token refresh in single interceptor
✅ Automatic retry on 401 responses
✅ Seamless user experience (no logout on token expiration)
✅ Local Hive storage for better performance
✅ Cleaner, more maintainable code
```

## How Token Injection Works

### Without Manual Headers
```dart
// OLD WAY - Manual header creation
final response = await http.get(
  Uri.parse('$baseUrl/api/v1/user/me/'),
  headers: _getAuthHeaders(),  // Must add manually
);

// NEW WAY - Automatic via interceptor
final response = await dio.get('/api/v1/user/me/');
// Token automatically added by AuthInterceptor ✅
```

### Token Refresh Flow
```
Request to API with access token
         ↓
Server returns 401 Unauthorized
         ↓
AuthInterceptor triggers token refresh:
  - Sends refresh token to /api/v1/auth/token/refresh/
  - Receives new access token
  - Stores new token in Hive
         ↓
Automatically retries original request with new token
         ↓
Request succeeds ✅
```

## Error Handling

The system gracefully handles:
1. **Expired access token** - Automatically refreshes
2. **Expired refresh token** - Clears all tokens, triggers login
3. **Network errors** - Proper error messages to user
4. **401 on refresh endpoint** - Identifies and prevents infinite loops

## Search Token Issue Resolution

**Problem:** Search was failing with "No access token available"

**Solution:** Dio interceptor automatically adds token to all requests:
- SearchUsers endpoint now receives Bearer token automatically
- No manual token checking needed before API calls
- Token refresh happens transparently on 401 responses

## Database Storage Details

**Hive Box:** `chat_tokens`
- **Key:** `access_token` → Value: JWT access token
- **Key:** `refresh_token` → Value: JWT refresh token
- **Storage:** Local encrypted database (platform-specific encryption)
- **Persistence:** Survives app restart

## Configuration

### BaseUrl (Changeable)
```dart
final apiService = ApiService(
  baseUrl: 'http://192.168.1.65:8000',  // Default
);

// Or update dynamically:
apiService.dio.options.baseUrl = 'http://new-server:8000';
```

### Token Refresh Timing
- Scheduled 5 minutes before expiration
- Triggered on 401 response (if not already expired)
- Non-blocking (doesn't freeze UI)

## Testing the System

### Check Token Status
```dart
final status = apiService.getTokenStatus();
print(status);
// Output: {hasToken: true, accessToken: ***, refreshToken: ***}
```

### Debug Hive Storage
```dart
final tokens = apiService.tokenStorage.getAllTokens();
print('Access Token: ${tokens['accessToken']}');
print('Refresh Token: ${tokens['refreshToken']}');
```

### Verify Token Injection
Look at console logs for:
```
🔐 Token added to request: /api/v1/user/me/
📡 GET /api/v1/user/me/ - Status: 200
```

## Files Changed/Created

### Created:
- `lib/services/hive_token_storage.dart` - Hive-based token storage
- `lib/services/dio_client.dart` - Dio HTTP client with interceptors
- `lib/services/api_service_new.dart` → renamed to `api_service.dart`
- `lib/services/token_manager_new.dart` → renamed to `token_manager.dart`

### Modified:
- `lib/main.dart` - Initialize Hive, pass to providers
- `pubspec.yaml` - Added hive & hive_flutter dependencies

### Deprecated (Kept for reference):
- `lib/services/api_service_old.dart` - Previous HTTP implementation
- `lib/services/token_manager_old.dart` - Previous SecureStorage implementation

## No More Manual Token Handling! 🎉

With this system, developers don't need to:
- ✅ Check if token exists before making requests
- ✅ Manually add Authorization headers
- ✅ Implement token refresh logic
- ✅ Handle 401 responses manually
- ✅ Show "login expired" messages for automatic token refresh

All handled transparently by the Dio interceptor! 🚀
