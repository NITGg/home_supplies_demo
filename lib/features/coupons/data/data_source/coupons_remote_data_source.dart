import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/coupons_model.dart';

abstract class CouponRemoteDataSource {
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 20});
}

class CouponRemoteDataSourceImpl implements CouponRemoteDataSource {
  final ApiClient _apiClient;

  CouponRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  @override
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '/customer-coupons',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      return CouponsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      log('CouponRemoteDataSource - DioException: ${e.message}');
      throw Exception(e.response?.data?['message'] ?? e.message ?? 'Network error');
    } catch (e) {
      log('CouponRemoteDataSource - Exception: $e');
      throw Exception('Unexpected error: $e');
    }
  }
}