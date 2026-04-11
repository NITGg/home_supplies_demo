import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/coupons_model.dart';

abstract class CouponRemoteDataSource {
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 20});
  Future<Coupon?> getFirstOrderCoupon();
  Future<int> getCompletedOrdersCount();
}

class CouponRemoteDataSourceImpl implements CouponRemoteDataSource {
  final ApiClient _apiClient;

  CouponRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  @override
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 1000}) async {
    final response = await _apiClient.dio.get(
      '/customer-coupons?lang=${LocaleManager.currentLocale}&is_first=false',
      queryParameters: {'page': page, 'limit': limit},
    );
    return CouponsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Coupon?> getFirstOrderCoupon() async {
    final response = await _apiClient.dio.get(
      '/customer-coupons',
      queryParameters: {
        'is_first': true,
        'lang': LocaleManager.currentLocale,
      },
    );
    final parsed =
    CouponsResponse.fromJson(response.data as Map<String, dynamic>);
    return parsed.coupons.isNotEmpty ? parsed.coupons.first : null;
  }

  @override
  Future<int> getCompletedOrdersCount() async {
    final response =
    await _apiClient.dio.get('/orders/stats/completed-count');
    final data = response.data as Map<String, dynamic>;
    return (data['total'] as num?)?.toInt() ?? 0;
  }
}