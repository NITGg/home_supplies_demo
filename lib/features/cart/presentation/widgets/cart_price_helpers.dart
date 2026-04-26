import '../../../orders/manager/order_states.dart';

// ── Price formatting ──────────────────────────────────────────────────────────

String fmtPrice(double v) => v.toStringAsFixed(2);

// ── Safe numeric coercions ────────────────────────────────────────────────────

double toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

bool toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  return v.toString().toLowerCase() == 'true';
}

// ── Coupon discount computations ──────────────────────────────────────────────

double? computeDeliveryFeeDiscount(CouponValid coupon, double rawFee) {
  if (!coupon.isDeliveryFeeDiscount) return null;
  final value = coupon.discountValueInEgp;
  if (value == null) return null;
  if (coupon.isPercentDiscount) return (rawFee * value / 100).clamp(0.0, rawFee);
  if (coupon.isFixedDiscount) return value.clamp(0.0, rawFee);
  return null;
}

double? computeCouponCartDiscount(CouponValid coupon, double subtotal) {
  if (coupon.isWalletCredit) return null;
  if (coupon.isDeliveryFeeDiscount) return null;
  final value = coupon.discountValueInEgp;
  if (value == null) return null;
  if (coupon.isPercentDiscount) return (subtotal * value / 100).clamp(0.0, subtotal);
  if (coupon.isFixedDiscount) return value.clamp(0.0, subtotal);
  return null;
}