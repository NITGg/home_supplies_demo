import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/create_order_sheet/coupon_section.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';
import '../../../orders/manager/order_cubit.dart';
import '../../../orders/manager/order_states.dart';
import '../../data/models/order_preview_model.dart';
import 'cart_discount_rows.dart';
import 'cart_payment_toggle.dart';
import 'cart_price_helpers.dart';
import 'cart_summary_row.dart';
import 'dashed_divider.dart';

class CartSummaryBar extends StatelessWidget {
  final dynamic summary;
  final OrderPreviewModel? preview;
  final double hPad;
  final double bottomPadding;
  final ThemeData theme;
  final AppLocalizations l10n;

  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;

  final TextEditingController couponController;
  final FocusNode couponFocus;
  final CouponValid? appliedCoupon;
  final bool couponValidating;
  final VoidCallback onValidateCoupon;
  final VoidCallback onRemoveCoupon;

  final VoidCallback onCheckout;
  final bool overCodLimit;
  final double codLimit;

  const CartSummaryBar({
    super.key,
    required this.summary,
    required this.preview,
    required this.hPad,
    required this.bottomPadding,
    required this.theme,
    required this.l10n,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.couponController,
    required this.couponFocus,
    required this.appliedCoupon,
    required this.couponValidating,
    required this.onValidateCoupon,
    required this.onRemoveCoupon,
    required this.onCheckout,
    this.overCodLimit = false,
    this.codLimit = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDiscount = toBool(summary.hasDiscount);
    final double originalTotal = toDouble(summary.originalTotal);
    final double totalDiscount = hasDiscount
        ? toDouble(summary.totalDiscount)
        : 0.0;
    final double priceBeforeCoupon = originalTotal - totalDiscount;

    final bool isOrderTotalCoupon =
        appliedCoupon?.isOrderTotalDiscount ?? false;

    // Prefer server-computed discountAmount (cap-aware) over local estimate.
    final bool hasServerDiscount =
        preview != null &&
        (preview?.discountAmount ?? 0) > 0 &&
        appliedCoupon != null;

    final double? couponDiscount =
        (appliedCoupon != null && !isOrderTotalCoupon)
        ? (hasServerDiscount && !appliedCoupon!.isDeliveryFeeDiscount
              ? preview!.discountAmount
              : computeCouponCartDiscount(appliedCoupon!, priceBeforeCoupon))
        : null;

    final double finalTotal = priceBeforeCoupon - (couponDiscount ?? 0.0);

    final double rawDeliveryFee = preview?.courierFee ?? 0.0;
    final double? deliveryFeeRounded = preview != null
        ? double.parse(rawDeliveryFee.toStringAsFixed(2))
        : null;
    final double? vatAmountRounded = preview?.vatAmount;

    final double? deliveryFeeDiscount =
        (appliedCoupon != null && preview != null && !isOrderTotalCoupon)
        ? (hasServerDiscount && appliedCoupon!.isDeliveryFeeDiscount
              ? preview?.discountAmount ?? 0
              : computeDeliveryFeeDiscount(appliedCoupon!, rawDeliveryFee))
        : null;
    final double? discountedDeliveryFee = deliveryFeeDiscount != null
        ? (rawDeliveryFee - deliveryFeeDiscount).clamp(0.0, rawDeliveryFee)
        : null;

    final double effectiveDeliveryFee =
        discountedDeliveryFee ?? deliveryFeeRounded ?? 0.0;

    final double platformFee = preview?.platformFee ?? 0.0;

    final double? grandTotalRaw = preview != null
        ? finalTotal + effectiveDeliveryFee + vatAmountRounded! + platformFee
        : null;

    final double? orderTotalCouponDiscount =
        (isOrderTotalCoupon && appliedCoupon != null && grandTotalRaw != null)
        ? (hasServerDiscount
              ? preview!.discountAmount
              : computeCouponCartDiscount(appliedCoupon!, grandTotalRaw))
        : null;

    final double? grandTotal = grandTotalRaw != null
        ? grandTotalRaw - (orderTotalCouponDiscount ?? 0.0)
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Coupon ───────────────────────────────────────────────────────
          CouponSection(
            couponController: couponController,
            couponFocus: couponFocus,
            appliedCoupon: appliedCoupon,
            couponValidating: couponValidating,
            onValidate: onValidateCoupon,
            onRemove: onRemoveCoupon,
          ),

          const SizedBox(height: 12),

          // ── COD limit notice ─────────────────────────────────────────────
          // Shown when the cart total exceeds the cash-on-delivery cap.
          // The toggle below remains visible so the user understands the
          // context, but CASH is greyed out and non-interactive.
          if (overCodLimit) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.walletBalanceHintOverBudget} ${codLimit.toStringAsFixed(2)} ${l10n.walletBalanceHintOverBudget2}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Payment toggle ───────────────────────────────────────────────
          // cashDisabled greys out the CASH tab inside CartPaymentToggle and
          // prevents tapping it, mirroring the create-order sheet behaviour.
          CartPaymentToggle(
            paymentMethod: paymentMethod,
            onChanged: overCodLimit
                ? (m) {
                    if (m != 'CASH') onPaymentMethodChanged(m);
                  }
                : onPaymentMethodChanged,
            l10n: l10n,
            cashDisabled: overCodLimit,
          ),

          const Divider(height: 24),

          // ── Item counts ──────────────────────────────────────────────────
          CartSummaryRow(
            label: l10n.numberOfItems,
            value: '${summary.itemCount}',
          ),
          const SizedBox(height: 4),

          CartSummaryRow(
            label: l10n.totalQuantity,
            value: '${summary.totalItems}',
          ),

          const Divider(height: 20),

          // ── Price breakdown ──────────────────────────────────────────────
          CartSummaryRow(
            label: l10n.cartTotal,
            value: '${fmtPrice(originalTotal)} ${l10n.egp}',
          ),

          if (hasDiscount) ...[
            const SizedBox(height: 6),
            CartDiscountRow(
              discount: totalDiscount,
              egp: l10n.egp,
              theme: theme,
            ),
          ],

          if (couponDiscount != null) ...[
            const SizedBox(height: 6),
            CartCouponDiscountRow(
              coupon: appliedCoupon!,
              discount: couponDiscount,
              egp: l10n.egp,
              theme: theme,
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: DashedDivider(color: theme.dividerColor),
          ),

          if (finalTotal != originalTotal)
            CartSummaryRow(
              label: l10n.subtotal,
              value: '${fmtPrice(finalTotal)} ${l10n.egp}',
            ),

          if (preview != null) ...[
            const SizedBox(height: 6),
            CartDeliveryFeeRow(
              original: deliveryFeeRounded!,
              discounted: discountedDeliveryFee,
              egp: l10n.egp,
              label: l10n.deliveryFee,
              theme: theme,
            ),
            CartDeliveryFeeRow(
              original: preview?.platformFee ?? 0,
              discounted: preview?.platformFee ?? 0,
              egp: l10n.egp,
              label: l10n.serviceFee,
              theme: theme,
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: DashedDivider(color: theme.dividerColor),
          ),

          if (orderTotalCouponDiscount != null) ...[
            CartCouponDiscountRow(
              coupon: appliedCoupon!,
              discount: orderTotalCouponDiscount,
              egp: l10n.egp,
              theme: theme,
            ),
            const SizedBox(height: 6),
          ],

          CartSummaryRow(
            label: '${l10n.deliveryFee} + ${l10n.subtotal}',
            value: grandTotal != null
                ? '${fmtPrice(grandTotal)} ${l10n.egp}'
                : '${fmtPrice(finalTotal)} ${l10n.egp}',
            isTotal: true,
          ),

          const SizedBox(height: 16),

          // ── Checkout button ──────────────────────────────────────────────
          BlocBuilder<OrderCubit, OrderState>(
            buildWhen: (_, s) =>
                s is OrderOperationLoading ||
                s is OrderSuccess ||
                s is OrderError ||
                s is OrdersLoaded,
            builder: (context, orderState) {
              final isLoading = orderState is OrderOperationLoading;
              return FilledButton.icon(
                onPressed: isLoading ? null : onCheckout,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  l10n.proceedToCheckout,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
