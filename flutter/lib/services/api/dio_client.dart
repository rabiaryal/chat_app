/// Dio HTTP client with automatic token injection and refresh
import 'package:dio/dio.dart';
import '../storage/hive_token_storage.dart';
import 'dart:async';
import '../../constants/api_constant.dart';

class AuthInterceptor extends Interceptor {
  final HiveTokenStorage tokenStorage;
  final String baseUrl;
  final Future<void> Function()? onSessionExpired;

  bool _isRefreshing = false;

  AuthInterceptor({
    required this.tokenStorage,
    required this.baseUrl,
    this.onSessionExpired,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final bool isAuthRequest = options.path.contains('/auth/login/') ||
        options.path.contains('/auth/register/');

    if (!isAuthRequest) {
      final accessToken = tokenStorage.getAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
        print('🔐 Token added to request: ${options.path}');
      }
    } else {
      print('🔐 Auth request detected, skipping token injection: ${options.path}');
    }

    options.headers['Content-Type'] = 'application/json';
    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.statusCode == 401) {
      print('⚠ Received 401 Unauthorized in onResponse');

      final requestOptions = response.requestOptions;

      if (requestOptions.path.contains('/auth/login/') ||
          requestOptions.path.contains('/auth/register/') ||
          requestOptions.path.contains('/auth/logout/')) {
        print('ℹ Skipping token refresh for auth endpoint: ${requestOptions.path}');
        return handler.next(response);
      }

      print('⚠ Attempting token refresh for: ${requestOptions.path}');

      if (requestOptions.path.contains('/token/refresh/')) {
        print('✗ Token refresh failed - refresh token expired or invalid');
        await tokenStorage.clearTokens();
        onSessionExpired?.call();
        return handler.next(response);
      }

      try {
        if (!_isRefreshing) {
          _isRefreshing = true;
          final refreshed = await _refreshAccessToken();
          _isRefreshing = false;

          if (refreshed) {
            print('✓ Token refreshed, retrying request: ${requestOptions.path}');
            return handler.resolve(await _retry(requestOptions));
          }
        } else {
          await Future.delayed(Duration(milliseconds: 100));
          return handler.resolve(await _retry(requestOptions));
        }
      } catch (e) {
        print('✗ Token refresh error in onResponse: $e');
      }
    }

    return handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // If the error status is 401, it's now handled in onResponse since we allow 401 in validateStatus.
    // This onError will still handle 500s or network failures.
    return handler.next(err);
  }

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
        ApiConstant.refreshToken,
        data: {'refresh': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
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
      await tokenStorage.clearTokens();
      onSessionExpired?.call();
      return false;
    }
  }

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
  final Future<void> Function()? onSessionExpired;

  DioClient({
    required this.tokenStorage,
    this.baseUrl = 'https://chat.rabiaryal.com.np',
    this.onSessionExpired,
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
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
        onSessionExpired: onSessionExpired,
      ),
    );

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

  void setBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }
}
