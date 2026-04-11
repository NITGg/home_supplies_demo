import '../data_source/coupons_remote_data_source.dart';
import '../models/coupons_model.dart';

abstract class CouponRepository {
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 20});
  Future<Coupon?> getFirstOrderCoupon();
  Future<int> getCompletedOrdersCount();
}

class CouponRepositoryImpl implements CouponRepository {
  final CouponRemoteDataSource _dataSource;

  CouponRepositoryImpl({CouponRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? CouponRemoteDataSourceImpl();

  @override
  Future<CouponsResponse> getCoupons({int page = 1, int limit = 20}) {
    return _dataSource.getCoupons(page: page, limit: limit);
  }

  @override
  Future<Coupon?> getFirstOrderCoupon() {
    return _dataSource.getFirstOrderCoupon();
  }

  @override
  Future<int> getCompletedOrdersCount() {
    return _dataSource.getCompletedOrdersCount();
  }
}