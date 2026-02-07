import 'package:dio/dio.dart';
import 'package:tawreedat_courier/core/utils/secure_storage_service.dart';
import 'dart:developer';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio dio;
  final SecureStorageService _storage = SecureStorageService();

  static const String baseUrl = 'https://tawreedat.nitg-eg.com/courier_apis/api/v1/courier';

  // Track if we're currently refreshing to avoid multiple refresh calls
  bool _isRefreshing = false;
  final List<void Function()> _requestsToRetry = [];

  void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip adding token for auth endpoints that don't need it
          if (_isAuthEndpoint(options.path)) {
            return handler.next(options);
          }

          // Add authorization token to all other requests
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },

        onError: (error, handler) async {
          // Check if error is 401 (Unauthorized) and not from refresh endpoint
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/refresh-token')) {

            // If already refreshing, queue this request
            if (_isRefreshing) {
              await _waitForRefresh();
              return _retry(error.requestOptions, handler);
            }

            _isRefreshing = true;

            try {
              // Attempt to refresh the token
              final newAccessToken = await _refreshToken();

              if (newAccessToken != null) {
                // Save the new token
                await _storage.saveToken(newAccessToken);

                // Retry all queued requests
                _executeQueuedRequests();

                // Retry the original request
                return _retry(error.requestOptions, handler);
              }
            } catch (e) {
              log('Token refresh failed: $e');
              // Clear session data
              await _clearSession();
              // You might want to emit an event here to force logout in UI
            } finally {
              _isRefreshing = false;
              _requestsToRetry.clear();
            }
          }

          handler.next(error);
        },
      ),
    );

    // Optional: Add logging interceptor for debugging
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: true,
        responseHeader: false,
        request: true,
      ),
    );
  }

  /// Check if the endpoint is an auth endpoint that doesn't need token
  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/verify-phone') ||
        path.contains('/auth/resend-phone-otp') ||
        path.contains('/auth/google/verify') ||
        path.contains('/auth/apple/verify');
  }

  /// Refresh the access token using refresh token
  Future<String?> _refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        log('No refresh token available');
        return null;
      }

      // Create a separate Dio instance to avoid interceptor recursion
      final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

      final response = await refreshDio.post(
        '/auth/refresh-token',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
        ),
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data']['accessToken'] as String;
      }

      return null;
    } catch (e) {
      log('Error refreshing token: $e');
      return null;
    }
  }

  /// Retry a failed request with new token
  Future<void> _retry(
      RequestOptions requestOptions,
      ErrorInterceptorHandler handler,
      ) async {
    try {
      final token = await _storage.getToken();

      // Update request with new token
      requestOptions.headers['Authorization'] = 'Bearer $token';

      // Retry the request
      final response = await dio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
          contentType: requestOptions.contentType,
        ),
      );

      handler.resolve(response);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: requestOptions,
          error: e,
        ),
      );
    }
  }

  /// Wait for ongoing refresh to complete
  Future<void> _waitForRefresh() async {
    while (_isRefreshing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Execute all queued requests after token refresh
  void _executeQueuedRequests() {
    for (var request in _requestsToRetry) {
      request();
    }
  }

  /// Clear session data when refresh fails
  Future<void> _clearSession() async {
    await _storage.deleteToken();
    await _storage.deleteRefreshToken();
    await _storage.deleteUserProfile();
  }
}