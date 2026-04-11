import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/coupons_model.dart';
import '../data/repositories/coupons_repo.dart';
import 'coupons_states.dart';

class CouponCubit extends Cubit<CouponState> {
  final CouponRepository _repository;

  // ── Cache loaded coupons so we can restore after first-order check ──
  CouponsLoaded? _lastLoadedState;

  CouponCubit({CouponRepository? repository})
    : _repository = repository ?? CouponRepositoryImpl(),
      super(CouponInitial());

  Future<void> loadCoupons() async {
    emit(CouponLoading());
    try {
      final response = await _repository.getCoupons();
      final loaded = CouponsLoaded(
        coupons: response.coupons,
        totalCoupons: response.totalCoupons,
        totalPages: response.totalPages,
      );
      _lastLoadedState = loaded; // ← cache it
      emit(loaded);
    } catch (e) {
      emit(CouponError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<Coupon?> checkFirstOrderDiscount() async {
    try {
      final count = await _repository.getCompletedOrdersCount();
      if (count != 0) return null;
      return await _repository.getFirstOrderCoupon();
    } catch (_) {
      return null;
    }
  }
}
