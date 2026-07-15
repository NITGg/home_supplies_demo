import '../data_source/coupons_remote_data_source.dart';
import '../models/coupns_model.dart';

class CouponRepository {
  final CouponDataSource _dataSource = CouponDataSource();

  Future<List<AvailableCouponModel>> getAvailableCoupons() =>
      _dataSource.getAvailableCoupons();

  Future<ActiveCouponModel?> getActiveCoupon() =>
      _dataSource.getActiveCoupon();

  Future<Map<String, dynamic>> getCouponHistory({
    int page = 1,
    int limit = 20,
  }) =>
      _dataSource.getCouponHistory(page: page, limit: limit);

  Future<void> buyCouponWithWallet(int couponId) =>
      _dataSource.buyCouponWithWallet(couponId);

  Future<void> buyCouponWithPoints(int couponId) =>
      _dataSource.buyCouponWithPoints(couponId);
}