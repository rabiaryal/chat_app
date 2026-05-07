/// Dio HTTP client with automatic token injection and refresh
import 'package:dio/dio.dart';
import 'hive_token_storage.dart';
import 'dart:async';

class AuthInterceptor extends Interceptor {
  final HiveTokenStorage tokenStorage;
  final String baseUrl;

  // Lock to prevent multiple token refresh requests
  bool _isRefreshing = false;

  AuthInterceptor({
    required this.tokenStorage,
    required this.baseUrl,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add access token to all requests
    final accessToken = tokenStorage.getAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
      print('🔐 Token added to request: ${options.path}');
    }

    options.headers['Content-Type'] = 'application/json';
    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    return handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized - token expired
    if (err.response?.statusCode == 401) {
      print('⚠ Received 401 Unauthorized');

      final requestOptions = err.requestOptions;

      // Skip token refresh for auth endpoints (login, register, logout)
      // These endpoints should return 401 for invalid credentials, not token expiration
      if (requestOptions.path.contains('/auth/login/') ||
          requestOptions.path.contains('/auth/register/') ||
          requestOptions.path.contains('/auth/logout/')) {
        print(
            'ℹ Skipping token refresh for auth endpoint: ${requestOptions.path}');
        return handler.next(err);
      }

      print('⚠ Attempting token refresh for: ${requestOptions.path}');

      // Check if this is already a refresh token request
      if (requestOptions.path.contains('/token/refresh/')) {
        print('✗ Token refresh failed - refresh token expired or invalid');
        // Clear tokens and let app handle logout
        await tokenStorage.clearTokens();
        return handler.next(err);
      }

      try {
        // Prevent multiple simultaneous refresh attempts
        if (!_isRefreshing) {
          _isRefreshing = true;

          // Attempt to refresh the token
          final refreshed = await _refreshAccessToken();

          _isRefreshing = false;

          if (refreshed) {
            // Retry original request with new token
            print(
                '✓ Token refreshed, retrying request: ${requestOptions.path}');
            return handler.resolve(await _retry(requestOptions));
          }
        } else {
          // Wait for refresh to complete, then retry
          await Future.delayed(Duration(milliseconds: 100));
          return handler.resolve(await _retry(requestOptions));
        }
      } catch (e) {
        print('✗ Token refresh error: $e');
      }
    }

    return handler.next(err);
  }

  /// Refresh the access token using refresh token
  Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        print('✗ No refresh token available');
        return false;
      }

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: 10),
        receiveTimeout: Duration(seconds: 10),
        validateStatus: (status) => status != null && status < 500,
      ));

      final response = await dio.post(
        '/api/v1/auth/token/refresh/',
        data: {'refresh': refreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access'];
        await tokenStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: refreshToken,
        );
        print('✓ Access token refreshed successfully');
        return true;
      } else {
        print('✗ Token refresh failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('✗ Error refreshing token: $e');
      // Clear tokens on refresh failure
      await tokenStorage.clearTokens();
      return false;
    }
  }

  /// Retry the original request with new token
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
      validateStatus: (status) => status != null && status < 500,
    ));

    // Add new token to retry request
    final accessToken = tokenStorage.getAccessToken();
    if (accessToken != null) {
      options.headers?['Authorization'] = 'Bearer $accessToken';
    }

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}

class DioClient {
  late Dio _dio;
  final HiveTokenStorage tokenStorage;
  final String baseUrl;

  DioClient({
    required this.tokenStorage,
    this.baseUrl = 'http://192.168.1.65:8000',
  }) {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: 10),
        receiveTimeout: Duration(seconds: 10),
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // Add auth interceptor
    _dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      ),
    );

    // Optional: Add logging interceptor for debugging
    _dio.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('📡 $obj'),
      ),
    );
  }

  Dio get dio => _dio;

  /// Update base URL (useful for environment changes)
  void setBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }
}
