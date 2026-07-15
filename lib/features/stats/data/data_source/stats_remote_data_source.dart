import 'package:dio/dio.dart';
import '../../../../../core/utils/api_client.dart';
import '../../../../core/utils/exception/api_exeption_mapper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/stats_models.dart';

class StatsRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;
  final Dio _dio2 = ApiClient.instance.dio2;

  /// GET EARNINGS SUMMARY
  Future<EarningsSummaryResponseModel> getEarningsSummary() async {
    try {
      final response = await _dio
          .get('/stat/earnings-summary?lang=${LocaleManager.currentLocale}');
      dLog('Get earnings summary response: ${response.data}');
      return EarningsSummaryResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      dLog('Get earnings summary error: $e');
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      dLog('Get earnings summary error: $e');
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// GET EARNINGS HISTORY
  Future<EarningsHistoryResponseModel> getEarningsHistory({
    required int page,
    required int limit,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
        'lang': LocaleManager.currentLocale,
      };
      if (startDate != null) queryParameters['created_atFrom'] = startDate;
      if (endDate != null) queryParameters['created_atTo'] = endDate;

      final response = await _dio.get(
        '/stat/earnings-history',
        queryParameters: queryParameters,
      );
      dLog('Get earnings history response: ${response.data}');
      return EarningsHistoryResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      dLog('Get earnings history error: $e');
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      dLog('Get earnings history error: $e');
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// GET PERFORMANCE
  Future<PerformanceResponseModel> getPerformance({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (startDate != null) queryParameters['start_date'] = startDate;
      if (endDate != null) queryParameters['end_date'] = endDate;

      final response = await _dio.get(
        '/stat/performance?lang=${LocaleManager.currentLocale}',
        queryParameters: queryParameters,
      );
      dLog('Get performance response: ${response.data}');
      return PerformanceResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      dLog('Get performance error: $e');
      throw ApiExceptionMapper.fromDio(e);
    } catch (e, s) {
      dLog('Get performance error: $e, $s');
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  /// GET BADGE PROGRESS
  Future<BadgeProgressResponseModel> getBadgeProgress() async {
    try {
      final response = await _dio2
          .get('/profile/wallet?lang=${LocaleManager.currentLocale}');
      dLog('Get badge progress response: ${response.data}');
      return BadgeProgressResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      dLog('Get badge progress error: $e');
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      dLog('Get badge progress error: $e');
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }
}