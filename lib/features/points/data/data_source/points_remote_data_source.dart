import 'package:dio/dio.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/exception/api_exeption_mapper.dart';
import '../../../../core/utils/exception/app_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/points_models.dart';

class PointsDataSource {
  final ApiClient _apiClient = ApiClient.instance;

  Future<PointsRulesModel> getPointsRules() async {
    try {
      final response = await _apiClient.dio
          .get('/points/rules?lang=${LocaleManager.currentLocale}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return PointsRulesModel.fromJson(response.data['data']);
      }
      throw const ParseException('Points rules data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<PointsProgressModel> getPointsProgress() async {
    try {
      final response = await _apiClient.dio
          .get('/points/progress?lang=${LocaleManager.currentLocale}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return PointsProgressModel.fromJson(response.data['data']);
      }
      throw const ParseException('Points progress data missing from response.');
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<void> payFinesUsingPoints({
    required List<int> penaltyIds,
    required List<int> commissionIds,
    required String userId,
  }) async {
    try {
      final response = await _apiClient.dio2.post(
        '/customer/points/pay-fines-using-points?lang=${LocaleManager.currentLocale}',
        data: {
          'penalty_ids': penaltyIds,
          'commission_ids': commissionIds,
          'user_id': userId,
        },
      );
      if (response.statusCode != 200) {
        dLog(response.data?['message']);
        throw BadRequestException(
          response.data?['message'] ?? 'Failed to pay fines using points',
        );
      }
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }

  Future<void> buyCouponUsingPoints({required int couponId}) async {
    try {
      final response = await _apiClient.dio.post(
        '/points/buy-coupon-using-points/$couponId?lang=${LocaleManager.currentLocale}',
      );
      if (response.statusCode != 200) {
        throw BadRequestException(
          response.data?['message'] ?? 'Failed to buy coupon using points',
        );
      }
    } on DioException catch (e) {
      throw ApiExceptionMapper.fromDio(e);
    } catch (e) {
      throw ApiExceptionMapper.fromUnknown(e);
    }
  }
}
 