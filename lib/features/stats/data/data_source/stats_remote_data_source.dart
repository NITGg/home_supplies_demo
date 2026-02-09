import 'dart:developer';

import 'package:dio/dio.dart';
import '../../../../../core/utils/api_client.dart';
import '../models/stats_models.dart';

class StatsRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// GET EARNINGS SUMMARY
  Future<EarningsSummaryResponseModel> getEarningsSummary() async {
    try {
      final response = await _dio.get(
        '/stat/earnings-summary?lang=ar',
      );

      log('Get earnings summary response: ${response.data}');
      return EarningsSummaryResponseModel.fromJson(response.data);
    } catch (e) {
      log('Get earnings summary error: $e');
      rethrow;
    }
  }

  /// GET EARNINGS HISTORY
  Future<EarningsHistoryResponseModel> getEarningsHistory({
    required int page,
    required int limit,
    int skip = 0,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
        'skip': skip,
      };

      if (startDate != null) {
        queryParameters['start_date'] = startDate;
      }
      if (endDate != null) {
        queryParameters['end_date'] = endDate;
      }

      final response = await _dio.get(
        '/stat/earnings-history?lang=ar',
        queryParameters: queryParameters,
      );

      log('Get earnings history response: ${response.data}');
      return EarningsHistoryResponseModel.fromJson(response.data);
    } catch (e) {
      log('Get earnings history error: $e');
      rethrow;
    }
  }

  /// GET PERFORMANCE
  Future<PerformanceResponseModel> getPerformance({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};

      if (startDate != null) {
        queryParameters['start_date'] = startDate;
      }
      if (endDate != null) {
        queryParameters['end_date'] = endDate;
      }

      final response = await _dio.get(
        '/stat/performance?lang=ar',
        queryParameters: queryParameters,
      );

      log('Get performance response: ${response.data}');
      return PerformanceResponseModel.fromJson(response.data);
    } catch (e,s) {
      log('Get performance error: $e, $s');
      rethrow;
    }
  }
}