import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/utils/secure_storage_service.dart';

import '../../main.dart';
import 'logger.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio dio;
  // late final Dio dioDEV;

  static const String baseUrl =
      'https://tawreedat.nitg-eg.com/admin_apis/api/v1';
  // static const String baseUrlDev = 'https://adminapis-dev.nitg-eg.com/api/v1';

  void init() {
    dio = _createDio(baseUrl);
  }

  Dio _createDio(String url) {
    final instance = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    instance.interceptors.add(_buildInterceptor(instance));
    return instance;
  }

  InterceptorsWrapper _buildInterceptor(Dio targetDio) {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // SEC-07: enforce 30-day max session age client-side
        final sessionStart = await SecureStorageService().getSessionStart();
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

        final token = await SecureStorageService().getToken();
        if (token != null && token.isNotEmpty) {
          // dLog('🔒 $token');
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        dLog('🌐 HTTP error: ${e.requestOptions.method} ${e.requestOptions.uri}');
        dLog('   status: ${e.response?.statusCode}');
        dLog('   body:   ${e.response?.data}');
        final friendlyError = _toFriendlyError(e);
        if (e.response?.statusCode == 401) {
          final token = await SecureStorageService().getToken();
          if (token != null && token.isNotEmpty) {
            dLog('🔒 401 on ${e.requestOptions.method} ${e.requestOptions.uri} — authenticated session expired, clearing');
            await _clearSession();
            // Absorb the error — _clearSession() already navigates to login,
            // so there's no cubit to notify and no UI left to show an error on.
            handler.reject(friendlyError);
            return;
          } else {
            // Guest hit an authenticated endpoint — log it so we can guard it properly
            dLog('⚠️ 401 on ${e.requestOptions.method} ${e.requestOptions.uri} — no token (guest), skipping redirect');
          }
        }
        handler.next(friendlyError);
      },
    );
  }
  Future<void> _clearSession() async {
    await SecureStorageService().clearAll();
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      GoRouter.of(context).go('/auth/login');
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
}
