import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/safe_emit_mixin.dart';
import '../data/models/coupons_model.dart';
import '../data/repositories/coupons_repo.dart';
import 'coupons_states.dart';

class CouponCubit extends Cubit<CouponState> with SafeEmitMixin<CouponState> {
  final CouponRepository _repository;
  String? pendingFirstOrderCouponCode;
  bool _firstOrderCheckDone = false;


  // ── Cache loaded coupons so we can restore after first-order check ──
  CouponsLoaded? _lastLoadedState;

  CouponCubit({CouponRepository? repository})
    : _repository = repository ?? CouponRepositoryImpl(),
      super(CouponInitial());

  Future<void> loadCoupons() async {
    safeEmit(CouponLoading());
    try {
      final response = await _repository.getCoupons();
      final loaded = CouponsLoaded(
        coupons: response.coupons,
        totalCoupons: response.totalCoupons,
        totalPages: response.totalPages,
      );
      _lastLoadedState = loaded; // ← cache it
      safeEmit(loaded);
    } catch (e) {
      safeEmit(CouponError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<String?> getOrFetchFirstOrderCoupon() async {
    // Already checked — return whatever we stored (could be null)
    if (_firstOrderCheckDone) return pendingFirstOrderCouponCode;

    _firstOrderCheckDone = true;
    try {
      final count = await _repository.getCompletedOrdersCount();
      if (count != 0) {
        pendingFirstOrderCouponCode = null;
        return null;
      }
      final coupon = await _repository.getFirstOrderCoupon();
      pendingFirstOrderCouponCode = coupon?.code;
      return pendingFirstOrderCouponCode;
    } catch (_) {
      pendingFirstOrderCouponCode = null;
      return null;
    }
  }

  Future<Coupon?> checkFirstOrderDiscount() async {
    try {
      final count = await _repository.getCompletedOrdersCount();
      if (count != 0) return null;
      final coupon = await _repository.getFirstOrderCoupon();
      if (coupon != null) {
        pendingFirstOrderCouponCode = coupon.code; // ← store it
      }
      return coupon;
    } catch (_) {
      return null;
    }
  }
}
