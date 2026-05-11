# Authentication Flow

The application uses **JWT (JSON Web Tokens)** for secure authentication between the Flutter frontend and Django backend.

## 1. Login/Register
- User submits credentials via `AuthScreen`.
- Backend returns `access` and `refresh` tokens.
- Frontend stores these tokens securely using **Hive** (`HiveTokenStorage`).
- /login and /register  endpints use the authintrecepetor so do not send token to these endpoints

## 2. Token Management
- **Access Token**: Short-lived (typically 5-60 minutes). Included in every request header as `Authorization: Bearer <token>`.
- **Refresh Token**: Long-lived (typically days/weeks). Used to obtain a new access token when it expires.

## 3. Automatic Token Refresh
Implemented via a **Dio Interceptor** (`AuthInterceptor` in `lib/services/dio_client.dart`):
1. A request fails with a `401 Unauthorized` error.
2. The interceptor catches the error.
3. It sends a request to `/api/v1/auth/token/refresh/` with the stored refresh token.
4. If successful, the new access token is saved and the original request is retried automatically.
5. If the refresh token is also expired, the user is logged out and redirected to the login screen.

## 4. Security
- Tokens are stored locally using Hive with optional encryption.
- Trimming is applied to input fields during login/register to prevent whitespace errors.
