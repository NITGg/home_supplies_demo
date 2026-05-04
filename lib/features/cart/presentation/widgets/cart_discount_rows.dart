import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/widgets/highlighter_widget.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';
import '../../../orders/manager/order_states.dart';
import 'cart_price_helpers.dart';

// ── Backend sale discount row ─────────────────────────────────────────────────

class CartDiscountRow extends StatelessWidget {
  final double discount;
  final String egp;
  final ThemeData theme;

  const CartDiscountRow({
    super.key,
    required this.discount,
    required this.egp,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.percent_rounded, size: 14),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.discount,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: HighlighterWidget(
            child: Text(
              '${fmtPrice(discount)} $egp',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Coupon discount row ───────────────────────────────────────────────────────

class CartCouponDiscountRow extends StatelessWidget {
  final CouponValid coupon;
  final double discount;
  final String egp;
  final ThemeData theme;

  const CartCouponDiscountRow({
    super.key,
    required this.coupon,
    required this.discount,
    required this.egp,
    required this.theme,
  });

  String _label(AppLocalizations l10n) {
    final value = coupon.discountValueInEgp;

    if (coupon.isDeliveryFeeDiscount) {
      if (coupon.isPercentDiscount && value != null) return '${value.toInt()}% ${l10n.offDeliveryFee}';
      if (coupon.isFixedDiscount && value != null) return '${fmtPrice(value)} $egp ${l10n.offDeliveryFee}';
      return coupon.title;
    }

    if (coupon.isPercentDiscount && value != null) return '${value.toInt()}% ${l10n.offYourOrder}';
    if (coupon.isFixedDiscount && value != null) return '${fmtPrice(value)} $egp ${l10n.offYourOrder}';
    return coupon.title;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer_outlined, size: 14),
            const SizedBox(width: 4),
            Text(
              _label(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: HighlighterWidget(
            key: ValueKey(discount),
            child: Text(
              '${fmtPrice(discount)} $egp',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Delivery fee row ──────────────────────────────────────────────────────────

class CartDeliveryFeeRow extends StatelessWidget {
  final double original;
  final double? discounted;
  final String egp;
  final String label;
  final ThemeData theme;

  const CartDeliveryFeeRow({
    super.key,
    required this.original,
    required this.discounted,
    required this.egp,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = discounted != null && discounted != original;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: hasDiscount
              ? Row(
            key: ValueKey('discounted_$discounted'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$original $egp',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade400,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.red.shade400,
                ),
              ),
              const SizedBox(width: 6),
              HighlighterWidget(
                child: Text(
                  '${discounted?.toStringAsFixed(2)} $egp',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          )
              : Text(
            key: ValueKey('normal_$original'),
            '${original.toStringAsFixed(2)} $egp',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}