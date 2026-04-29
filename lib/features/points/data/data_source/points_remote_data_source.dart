import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/points_models.dart';

class PointsDataSource {
  final ApiClient _apiClient = ApiClient.instance;

  // ==================== Get Points Rules ====================
  Future<PointsRulesModel> getPointsRules() async {
    final response = await _apiClient.dio.get(
      '/customer/points/rules?lang=${LocaleManager.currentLocale}',
    );
    if (response.statusCode == 200 && response.data['data'] != null) {
      return PointsRulesModel.fromJson(response.data['data']);
    }
    throw Exception('Failed to fetch points rules');
  }

  // ==================== Get Points Progress ====================
  Future<PointsProgressModel> getPointsProgress() async {
    final response = await _apiClient.dio.get(
      '/customer/points/progress?lang=${LocaleManager.currentLocale}',
    );
    if (response.statusCode == 200 && response.data['data'] != null) {
      return PointsProgressModel.fromJson(response.data['data']);
    }
    throw Exception('Failed to fetch points progress');
  }

  // ==================== Convert Points to Money ====================
  Future<void> convertPointsToMoney({
    required String userId,
    required int pointsToMoney,
  }) async {
    final response = await _apiClient.dio.post(
      '/customer/points/convert-points-to-money',
      data: {
        'userId': userId,
        'piontsToMoney': pointsToMoney, // keep server spelling
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        response.data?['message'] ?? 'Failed to convert points to money',
      );
    }
  }

  // ==================== Pay Fines Using Points ====================
  Future<void> payFinesUsingPoints({
    required List<int> penaltyIds,
  }) async {
    final response = await _apiClient.dio.post(
      '/customer/points/pay-fines-using-points',
      data: {'penalty_ids': penaltyIds},
    );
    if (response.statusCode != 200) {
      throw Exception(
        response.data?['message'] ?? 'Failed to pay fines using points',
      );
    }
  }
}