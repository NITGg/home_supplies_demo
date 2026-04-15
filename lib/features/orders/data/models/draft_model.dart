
import '../../../addresses/data/models/address_model.dart';
import '../../manager/order_states.dart';

/// Persists [CreateOrderBottomSheet] form state across open/close cycles.
/// All fields are static — no instance needed. Call [clear] after a successful
/// order submission so the next opening starts fresh.
class CreateOrderDraft {
  CreateOrderDraft._();

  // ── Text fields ────────────────────────────────────────────────────────────
  static String productDescription = '';
  static String budget = '';
  static String couponCode = '';

  // ── Address selections ─────────────────────────────────────────────────────
  static Address? pickupAddress;
  static Address? deliveryAddress;

  // ── Toggle / radio state ───────────────────────────────────────────────────
  static bool isShopping = true;
  static String paymentMethod = 'CASH';
  static bool pickupNearMe = false;

  // ── Applied coupon ─────────────────────────────────────────────────────────
  static CouponValid? appliedCoupon;

  // ── Reset ──────────────────────────────────────────────────────────────────
  static void clear() {
    productDescription = '';
    budget = '';
    couponCode = '';
    pickupAddress = null;
    deliveryAddress = null;
    isShopping = true;
    paymentMethod = 'CASH';
    pickupNearMe = false;
    appliedCoupon = null;
  }
}