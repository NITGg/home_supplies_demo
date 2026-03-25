import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:tawreedat_go/core/utils/secure_storage_service.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio dio;

  static const String baseUrl =
      'https://tawreedat.nitg-eg.com/admin_apis/api/v1';

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
          final token = await SecureStorageService().getToken();
          // log('Token: $token');
          if (token != null && token.isNotEmpty) {
            // Add the authorization token to the headers
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          final friendlyError = _toFriendlyError(e);

          handler.next(friendlyError);
        },
      ),
    );
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
        if (statusCode != null && statusCode >= 500) {
          message = 'خطأ في الخادم، يرجى المحاولة لاحقاً';
        }
        break;
      case DioExceptionType.cancel:
        message = 'تم إلغاء الطلب';
        break;
      default:
        break; // leave message null → keep original error
    }

    if (message == null) return error;

    return DioException(
      requestOptions: error.requestOptions,
      response: error.response,
      type: error.type,
      error: message,
      message: message,
    );
  }
}
