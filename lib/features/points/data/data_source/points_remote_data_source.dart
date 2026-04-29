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
}