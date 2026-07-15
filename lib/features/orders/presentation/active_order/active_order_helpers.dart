
//courier

import 'package:flutter/material.dart';

import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/orders_model.dart';

// ── Shared discount-hint widget ───────────────────────────────────────────────

class CourierDiscountHint extends StatelessWidget {
  final String message;
  final IconData icon;

  const CourierDiscountHint({
    super.key,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper: build all applicable discount hints for an order ─────────────────

List<Widget> buildDiscountHints(OrderModel order, AppLocalizations l10n) {
  final hints = <Widget>[];
  final rawDiscount = double.tryParse(order.discountAmount ?? '0') ?? 0;

  double capped(String? originalStr) {
    final original = double.tryParse(originalStr ?? '0') ?? 0;
    if (original <= 0) return rawDiscount;
    return rawDiscount.clamp(0.0, original);
  }

  String fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  if (order.hasDeliveryFeeDiscount) {
    final amount = fmt(capped(order.courierFee ?? order.totalFee));
    hints.add(
      CourierDiscountHint(
        icon: Icons.local_shipping_outlined,
        message: '${l10n.customerDeliveryDiscount}: $amount ${l10n.egp}',
      ),
    );
  }

  if (order.hasProductsOnlyDiscount) {
    final originalPrice = order.actualPrice ?? order.budget;
    final amount = fmt(capped(originalPrice));
    hints.add(
      CourierDiscountHint(
        icon: Icons.shopping_bag_outlined,
        message: '${l10n.customerProductDiscount}: $amount ${l10n.egp}',
      ),
    );
  }

  if (order.hasOrderTotalDiscount) {
    final amount = fmt(capped(order.payableAmount));
    hints.add(
      CourierDiscountHint(
        icon: Icons.receipt_long_outlined,
        message: '${l10n.customerOrderTotalDiscount}: $amount ${l10n.egp}',
      ),
    );
  }

  if (hints.isEmpty) return [];

  final spaced = <Widget>[];
  for (int i = 0; i < hints.length; i++) {
    spaced.add(hints[i]);
    if (i < hints.length - 1) spaced.add(const SizedBox(height: 6));
  }
  return spaced;
}
// ── Helper: compute original and after-discount double values ────────────────

({double original, double afterDiscount}) computeDiscounted(
    String? rawAmount,
    String? discountStr,
    ) {
  final original = double.tryParse(rawAmount ?? '0') ?? 0;
  final discount = double.tryParse(discountStr ?? '0') ?? 0;
  return (
  original: original,
  afterDiscount: (original - discount).clamp(0, double.infinity),
  );
}

// ── Widget: strikethrough original + green after-discount value ──────────────

class DiscountedValue extends StatelessWidget {
  final double original;
  final double afterDiscount;
  final String currency;
  final TextStyle? baseStyle;

  const DiscountedValue({
    super.key,
    required this.original,
    required this.afterDiscount,
    required this.currency,
    this.baseStyle,
  });

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final hasDiscount = afterDiscount < original;
    final style = baseStyle ?? AppTextStyles.bold14;

    if (!hasDiscount) {
      return Text('${_fmt(original)} $currency', style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_fmt(original)} $currency',
          style: style.copyWith(
            decoration: TextDecoration.lineThrough,
            color: Colors.grey.shade500,
            fontSize: (style.fontSize ?? 14) - 2,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_fmt(afterDiscount)} $currency',
              style: style.copyWith(color: Colors.green.shade700),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '↓ ${_fmt(original - afterDiscount)} $currency',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}