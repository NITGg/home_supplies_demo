import 'package:flutter/material.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';
import '../../../../../../core/style/app_colors.dart';
import '../../../../../../core/style/text_styles.dart';
import '../../../../../../core/widgets/text_form.dart';
import '../../../../manager/order_states.dart';

class CouponSection extends StatelessWidget {
  final TextEditingController couponController;
  final FocusNode couponFocus;
  final CouponValid? appliedCoupon;
  final bool couponValidating;
  final VoidCallback onValidate;
  final VoidCallback onRemove;

  const CouponSection({
    super.key,
    required this.couponController,
    required this.couponFocus,
    required this.appliedCoupon,
    required this.couponValidating,
    required this.onValidate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (appliedCoupon != null) {
      return AppliedCouponBadge(coupon: appliedCoupon!, onRemove: onRemove);
    }

    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: AppTextFormField(
            controller: couponController,
            focusNode: couponFocus,
            label: l10n.couponCode,
            validator: (v) => null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onValidate(),
            prefixIcon: const Icon(
              Icons.local_offer_outlined,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: onValidate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              elevation: 0,
            ),
            child: couponValidating
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(l10n.applyCoupon, style: AppTextStyles.bold14),
          ),
        ),
      ],
    );
  }
}

class AppliedCouponBadge extends StatelessWidget {
  final CouponValid coupon;
  final VoidCallback onRemove;

  const AppliedCouponBadge({
    super.key,
    required this.coupon,
    required this.onRemove,
  });

  String _buildRewardText(AppLocalizations l10n) {
    if (coupon.isWalletCredit) {
      final parts = <String>[];
      if (coupon.walletAmountCents != null && coupon.walletAmountCents! > 0) {
        final egp = (coupon.walletAmountCents! / 100).toStringAsFixed(2);
        parts.add(l10n.walletCredit(egp));
      }
      if (coupon.walletPoints != null && coupon.walletPoints! > 0) {
        parts.add(l10n.walletPoints(coupon.walletPoints!));
      }
      return parts.join(' & ');
    }

    if (coupon.discountValue != null) {
      // ── Determine what the discount applies to ──────────────────────────
      final target = coupon.isDeliveryFeeDiscount
          ? l10n.offDeliveryFee   // ← new string
          : l10n.offYourOrder;

      if (coupon.isPercentDiscount) {
        return '${coupon.discountValue!.toStringAsFixed(0)}% $target';
      }
      if (coupon.isFixedDiscount) {
        return '${coupon.discountValue!.toStringAsFixed(0)} ${l10n.egp} $target';
      }
    }

    return '';
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reward = _buildRewardText(l10n);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                if (reward.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reward,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  coupon.code,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade600,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.green.shade700, size: 18),
            onPressed: onRemove,
            tooltip: l10n.removeCoupon,
          ),
        ],
      ),
    );
  }
}
