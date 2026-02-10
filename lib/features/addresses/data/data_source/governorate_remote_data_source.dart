import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../models/governorate_model.dart';

class GovernorateRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<GovernoratesResponse> getGovernoratesWithAreas() async {
    try {
      log('Fetching governorates with areas');

      final response = await _dio.get(
        '/governorates?includes=areas',
      );

      log('Get governorates response: ${response.data}');

      if (response.statusCode == 200) {
        return GovernoratesResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load governorates');
      }
    } on DioException catch (e) {
      log('Get governorates error: $e');
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final message = e.response?.data['message'] ??
          e.response?.data['error'] ??
          'An error occurred';
      return message;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}