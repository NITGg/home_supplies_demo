import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/utils/secure_storage_service.dart';
import 'package:tawreedat_courier/core/utils/socket_service.dart';
import 'dart:async';

import '../../main.dart';
import 'logger.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio dio;
  late final Dio dio2;
  final SecureStorageService _storage = SecureStorageService();

  static const String baseUrl =
      'https://tawreedat.nitg-eg.com/home_supplies/courier/api/v1/courier';
  static const String baseUrl2 =
      'https://tawreedat.nitg-eg.com/home_supplies/admin/api/v1';

  // ── Refresh state ─────────────────────────────────────────────────────────
  // A single Completer acts as both the "in-flight" flag and the broadcast
  // channel for every request that arrives while a refresh is already running.
  // All waiters await the same future; when it completes they all unblock with
  // the same result — no polling, no empty queue.
  Completer<String?>? _refreshCompleter;

  bool _isdLoggingOut = false;

  void init() {
    dio  = _createDio(baseUrl);
    dio2 = _createDio(baseUrl2);

    SocketService().setTokenRefreshCallback(_ensureTokenRefreshed);
  }

  /// Single source of truth for Dio configuration.
  /// Any new interceptor, timeout, or header added here applies to both clients.
  Dio _createDio(String url) {
    final instance = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    instance.interceptors.add(_buildInterceptor(instance));
    return instance;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Interceptor factory
  // ─────────────────────────────────────────────────────────────────────────

  InterceptorsWrapper _buildInterceptor(Dio targetDio) {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_isAuthEndpoint(options.path)) return handler.next(options);

        // SEC-07: enforce 30-day max session age client-side
        final sessionStart = await _storage.getSessionStart();
        if (sessionStart != null &&
            DateTime.now().difference(sessionStart).inDays >= 30) {
          dLog('⏰ Session older than 30 days — forcing re-login');
          await _clearSession();
          handler.reject(DioException(
            requestOptions: options,
            message: 'Session expired — please log in again',
          ));
          return;
        }

        final token = await _storage.getToken();
        dLog('🔒 $token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },

      onError: (error, handler) async {

        if (error.response?.statusCode == 401){
          _clearSession();
        }

        // ── Clean up error messages ──────────────────────────────────────
        final friendlyError = _toFriendlyError(error);

        final isJwtExpired =
            error.response?.statusCode == 500 &&
            (error.response?.data['message']?.toString().contains(
                      'jwt expired',
                    ) ==
                    true ||
                error.response?.data['message']?.toString().contains(
                      'jwt malformed',
                    ) ==
                    true) &&
            !error.requestOptions.path.contains('/auth/refresh-token');

        if (!isJwtExpired) return handler.next(friendlyError);

        // ── Route ALL callers through the shared lock ──────────────────────
        final newToken = await _ensureTokenRefreshed();

        if (newToken != null) {
          return _retry(error.requestOptions, handler, targetDio, newToken); // ← pass token
        }

        // Refresh failed — session has already been cleared inside
        // _ensureTokenRefreshed; just propagate the original error.
        handler.next(friendlyError);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single refresh entry-point (shared by HTTP interceptor + SocketService)
  // ─────────────────────────────────────────────────────────────────────────

  /// Refreshes the access token exactly once no matter how many concurrent
  /// callers arrive.  Every caller — HTTP interceptor or socket — awaits the
  /// same [Completer] future, so only a single network call is ever made.
  ///
  /// Returns the new access token on success, or `null` on failure (in which
  /// case the session has already been cleared).

// ── _ensureTokenRefreshed — retries on network errors ────────────────────────

  Future<String?> _ensureTokenRefreshed() async {
    if (_refreshCompleter != null) {
      dLog('⏳ Refresh already in-flight — waiting for result...');
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      const maxNetworkRetries = 3;
      const retryDelay = Duration(seconds: 4);

      for (int attempt = 1; attempt <= maxNetworkRetries; attempt++) {
        final result = await _refreshToken();

        if (result.succeeded) {
          await _storage.saveToken(result.token!);
          dLog('✅ Token refreshed successfully');
          _refreshCompleter!.complete(result.token);
          return result.token;
        }

        if (result.failure == _RefreshFailure.authRejected) {
          // 401/403/500 from the refresh endpoint — refresh token is dead.
          dLog('❌ Refresh token rejected by server — clearing session');
          _refreshCompleter!.complete(null);
          await _clearSession();
          return null;
        }

        // Network error — retry unless we've exhausted attempts.
        if (attempt < maxNetworkRetries) {
          dLog('⚠️ Network error during refresh (attempt $attempt/$maxNetworkRetries) — retrying in ${retryDelay.inSeconds}s');
          await Future.delayed(retryDelay);
        } else {
          dLog('❌ Network error during refresh — all $maxNetworkRetries attempts failed — clearing session');
          _refreshCompleter!.complete(null);
          await _clearSession();
          return null;
        }
      }

      // Unreachable but satisfies the compiler.
      _refreshCompleter!.complete(null);
      return null;
    } catch (e) {
      dLog('❌ Token refresh threw unexpectedly: $e');
      _refreshCompleter!.complete(null);
      await _clearSession();
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/dLogin') ||
        path.contains('/auth/register') ||
        path.contains('/auth/verify-phone') ||
        path.contains('/auth/resend-phone-otp') ||
        path.contains('/auth/google/verify') ||
        path.contains('/auth/apple/verify');
  }

  /// Makes the actual network call to exchange the refresh token for a new
  /// access token.  Uses a dedicated [Dio] instance to avoid interceptor
  /// recursion.  Returns `null` on any failure.
  Future<_RefreshResult> _refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        dLog('⚠️ No refresh token available');
        return const _RefreshResult.fail(_RefreshFailure.authRejected);
      }

      final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await refreshDio.post(
        '/auth/refresh-token',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final newAccessToken = response.data['data']['accessToken'] as String;
        return _RefreshResult.success(newAccessToken);
      }

      dLog('⚠️ Refresh endpoint returned unexpected response: ${response.statusCode}');
      return const _RefreshResult.fail(_RefreshFailure.authRejected);

    } on DioException catch (e) {
      final status = e.response?.statusCode;

      // Definitive auth rejection — refresh token is dead.
      if (status == 401 || status == 403 || status == 500) {
        dLog('🔑 Refresh token rejected (HTTP $status)');
        return const _RefreshResult.fail(_RefreshFailure.authRejected);
      }

      // Everything else (connection reset, timeout, DNS failure…) is transient.
      dLog('⚠️ Network error during refresh: $e');
      return const _RefreshResult.fail(_RefreshFailure.networkError);

    } catch (e) {
      dLog('❌ Unexpected error during refresh: $e');
      return const _RefreshResult.fail(_RefreshFailure.networkError);
    }
  }

  Future<void> _retry(
      RequestOptions requestOptions,
      ErrorInterceptorHandler handler,
      Dio targetDio,
      String freshToken, // ← accept token explicitly
      ) async {
    try {
      // Stamp the fresh token directly — no storage round-trip, no race condition
      requestOptions.headers['Authorization'] = 'Bearer $freshToken';

      // fetch() replays the exact original RequestOptions (all fields preserved)
      // and skips re-running the error interceptor, preventing infinite loops
      final response = await targetDio.fetch(requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.reject(e);
    } catch (e) {
      handler.reject(DioException(requestOptions: requestOptions, error: e));
    }
  }

  Future<void> _clearSession() async {
    if (_isdLoggingOut) return;
    _isdLoggingOut = true;

    try {
      await _storage.deleteToken();
      await _storage.deleteRefreshToken();
      await _storage.deleteUserProfile();

      SocketService().stop();

      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        GoRouter.of(context).go('/auth/login');
      } else {
        dLog('⚠️ No valid context available for navigation');
      }

      dLog('🔌 Session cleared — redirected to dLogin');
    } catch (e) {
      dLog('⚠️ Error during session clear: $e');
    } finally {
      // Always reset so that if the user dLogs back in within the same app
      // session, a future expiry will still trigger a proper dLogout.
      _isdLoggingOut = false;
    }
  }


  DioException _toFriendlyError(DioException error) {
    String? message;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'انتهت مهلة الاتصال، يرجى المحاولة مرة أخرى';
        break;
      case DioExceptionType.connectionError:
        message = 'تعذر الاتصال بالخادم، تحقق من اتصالك بالإنترنت';
        break;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          message = 'الخادم غير متاح حالياً، يرجى المحاولة لاحقاً';
        } else if (statusCode != null && statusCode >= 500) {
          dLog('HTTP $statusCode — ${error.response?.data}');
          message = 'خطأ في الخادم، يرجى المحاولة لاحقاً';
        }
        break;
      case DioExceptionType.cancel:
        message = 'تم إلغاء الطلب';
        break;
      default:
        break;
    }

    if (message == null) return error;

    return DioException(
      requestOptions: error.requestOptions,
      response: error.response != null
          ? Response(
        requestOptions: error.requestOptions,
        statusCode: error.response!.statusCode,
        data: message, // ← replaces raw HTML with the Arabic message
      )
          : null,
      type: error.type,
      error: message,
      message: message,
    );
  }


  // void _startTokenSabotageTimer() {
  //   // After 2 minutes, kill tokens
  //   Future.delayed(const Duration(seconds: 20), () async {
  //     dLog('🧨 Sabotaging tokens for testing...');
  //
  //     await _storage.saveToken('INVALID_TOKEN');
  //     await _storage.saveRefreshToken('INVALID_REFRESH');
  //
  //     dLog('🧨 Tokens sabotaged');
  //   });
  // }
}
// ── Result type ───────────────────────────────────────────────────────────────
enum _RefreshFailure { authRejected, networkError }

class _RefreshResult {
  final String? token;
  final _RefreshFailure? failure;

  const _RefreshResult.success(this.token) : failure = null;
  const _RefreshResult.fail(this.failure)  : token   = null;

  bool get succeeded => token != null;
}