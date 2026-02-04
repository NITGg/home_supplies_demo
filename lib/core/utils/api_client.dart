import 'package:dio/dio.dart';
import 'package:tawreedat/core/utils/secure_storage_service.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio dio;

  static const String baseUrl = 'https://tawreedatapis.nitg-eg.com';

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
          if (token != null && token.isNotEmpty) {
            // Add the authorization token to the headers
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          handler.next(e);
        },
      ),
    );
  }
}
