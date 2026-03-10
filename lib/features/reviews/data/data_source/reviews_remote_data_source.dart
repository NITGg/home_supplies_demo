import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/reviews_model.dart';

class ReviewsRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<ReviewsResponse> getMyReviews({
    int skip = 0,
    int limit = 20,
    String sort = '-created_at',
  }) async {
    try {
      final response = await _dio.get(
        '/courier-reviews?lang=ar',
        queryParameters: {
          'skip': skip,
          'limit': limit,
          'sort': sort,
        },
      );
      return ReviewsResponse.fromJson(response.data);
    } catch (e) {
      log('Get reviews error: $e');
      rethrow;
    }
  }
}