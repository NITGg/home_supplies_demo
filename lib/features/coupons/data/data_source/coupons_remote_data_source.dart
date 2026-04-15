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
    final now = DateTime.now().toIso8601String();
    final response = await _apiClient.dio.get(
      '/customer-coupons?lang=${LocaleManager.currentLocale}&is_first=false',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sort': 'id',
        'OR[0][AND][0][start_at][lte]': now,
        'OR[0][AND][1][end_at][gte]': now,
        'OR[1][start_at]': null,
        'OR[2][end_at]': null,
      },
    );
    return CouponsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Coupon?> getFirstOrderCoupon() async {
    final now = DateTime.now().toIso8601String();

    final response = await _apiClient.dio.get(
      '/customer-coupons',
      queryParameters: {
        'is_first': true,
        'lang': LocaleManager.currentLocale,
        'OR[0][AND][0][start_at][lte]': now,
        'OR[0][AND][1][end_at][gte]': now,
        'OR[1][start_at]': null,
        'OR[2][end_at]': null,
      },
    );
    final parsed = CouponsResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    return parsed.coupons.isNotEmpty ? parsed.coupons.first : null;
  }

  @override
  Future<int> getCompletedOrdersCount() async {
    final response = await _apiClient.dio.get('/orders/stats/completed-count');
    final data = response.data as Map<String, dynamic>;
    return (data['total'] as num?)?.toInt() ?? 0;
  }
}
