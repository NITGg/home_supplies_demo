import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/exception/api_exeption_mapper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/reviews_model.dart';

class ReviewsRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<ReviewsResponse> getMyReviews({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/review/all-reviews?lang=${LocaleManager.currentLocale}',
        queryParameters: {'page': page, 'limit': limit, 'ratingFrom': 1},
      );
      dLog('Reviews response: ${response.data}');
      return ReviewsResponse.fromJson(response.data);
    } on DioException catch (e) {
      dLog('Get reviews error: $e');
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      dLog('Get reviews error: $e');
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }
}