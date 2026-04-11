import '../data/models/coupons_model.dart';

abstract class CouponState {}

class CouponInitial extends CouponState {}

class CouponLoading extends CouponState {}

class CouponsLoaded extends CouponState {
  final List<Coupon> coupons;
  final int totalCoupons;
  final int totalPages;

  CouponsLoaded({
    required this.coupons,
    required this.totalCoupons,
    required this.totalPages,
  });

  List<Coupon> get activeCoupons => coupons.where((c) => c.isActive).toList();
}

class CouponError extends CouponState {
  final String message;
  CouponError(this.message);
}

// ── NEW: emitted when the user qualifies for a first-order discount ──────────
class FirstOrderCouponAvailable extends CouponState {
  final Coupon coupon;
  FirstOrderCouponAvailable(this.coupon);
}

class FirstOrderCouponChecked extends CouponState {} // no coupon / already ordered
// ────────────────────────────────────────────────────────────────────────────