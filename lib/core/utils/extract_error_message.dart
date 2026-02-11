import 'package:dio/dio.dart';

String extractErrorMessage(dynamic e) {
  // Default message
  String message = 'حدث خطأ غير متوقع';

  if (e is DioException) {
    // Check for timeout types
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'الانترنت غير مستقر'; // "Internet not stable"
    } else {
      // Try to extract message from response
      try {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'];
        } else if (data is String) {
          message = data;
        }
      } catch (_) {}
    }
  } else {
    message = e.toString();
  }

  return message;
}
