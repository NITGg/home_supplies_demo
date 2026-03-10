import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/coupons_model.dart';

abstract class CouponRemoteDataSource {
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 20});
}

class CouponRemoteDataSourceImpl implements CouponRemoteDataSource {
  final ApiClient _apiClient;

  CouponRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  @override
  // Replace entire try/catch with nothing:
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 20}) async {
    final response = await _apiClient.dio.get(
      '/customer-coupons?lang=${LocaleManager.currentLocale}',
      queryParameters: {'page': page, 'limit': limit},
    );
    return CouponsResponse.fromJson(response.data as Map<String, dynamic>);
  }
}