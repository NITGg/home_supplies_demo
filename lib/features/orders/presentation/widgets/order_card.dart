import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/calculate_distance.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/orders_model.dart';

class OrderCardWidget extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final bool isDimmed;

  const OrderCardWidget({
    super.key,
    required this.order,
    required this.onTap,
    this.isDimmed = false,
  });

  // ─── status helpers ────────────────────────────────────────────────────────

  Color _statusColor() {
    if (order.proposalHistory != null && order.proposalHistory!.isNotEmpty) {
      switch (order.proposalHistory!.last.status) {
        case 'PENDING':
          return Colors.blue;
        case 'ACCEPTED':
          return Colors.green;
        case 'REJECTED':
          return Colors.red;
      }
    }
    switch (order.status) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon() {
    if (order.proposalHistory != null && order.proposalHistory!.isNotEmpty) {
      switch (order.proposalHistory!.last.status) {
        case 'PENDING':
          return Icons.schedule;
        case 'ACCEPTED':
          return Icons.check_circle;
        case 'REJECTED':
          return Icons.cancel;
      }
    }
    switch (order.status) {
      case 'PENDING':
        return order.budget == '0.01' ? Icons.inventory : Icons.shopping_bag;
      case 'IN_PROGRESS':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _statusLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (order.proposalHistory != null && order.proposalHistory!.isNotEmpty) {
      switch (order.proposalHistory!.last.status) {
        case 'PENDING':
          return l10n.offerSubmitted;
        case 'ACCEPTED':
          return l10n.offerAccepted;
        case 'REJECTED':
          return l10n.offerRejected;
      }
    }
    switch (order.status) {
      case 'PENDING':
        return l10n.pending;
      case 'IN_PROGRESS':
        return l10n.inProgress;
      case 'DELIVERED':
        return l10n.delivered;
      case 'CANCELLED':
        return l10n.cancelled;
      case 'EXPIRED':
        return l10n.expired;
      case 'SEARCHING_FAILED':
        return l10n.searchingFailed;
      default:
        return order.status;
    }
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final statusColor = order.isOutOfPriceRange ? Colors.grey : _statusColor();
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName == 'ar';

    return Opacity(
      opacity: isDimmed || order.isOutOfPriceRange ? 0.45 : 1.0,
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: AppColors.kPrimaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, statusColor.withOpacity(0.03)],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Product image (fixed 52 × 52) ───────────────────────
                  Hero(
                    tag: 'order-image-${order.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ImageWithIconFallback(
                        imageUrl: order.productImage,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        iconSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Middle: description + meta ───────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productDescription ?? order.orderNumber,
                          style: AppTextStyles.bold14.copyWith(
                            fontSize: 14,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 11,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              flex: 2,
                              child: Text(
                                formatDate(context, order.createdAt),
                                style: AppTextStyles.regular14.copyWith(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ── Status badge ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(), size: 11, color: Colors.white),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _statusLabel(context),
                            style: AppTextStyles.bold14.copyWith(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Spacer(),
              // ── Info chips ───────────────────────────────────────────────
              Wrap(
                verticalDirection: VerticalDirection.up,
                runAlignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (order.budget != '0.01' && order.budget != null)
                    _infoChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '${order.budget} ${l10n.egp}',
                      color: AppColors.kSecondaryColor,
                    ),
                  if (order.pickupArea != null)
                    _infoChip(
                      icon: Icons.store_outlined,
                      label: isArabic
                          ? order.pickupArea!.nameAr
                          : order.pickupArea!.name,
                      color: Colors.blue,
                    ),
                  if (order.deliveryArea != null)
                    _infoChip(
                      icon: Icons.location_on_outlined,
                      label: isArabic
                          ? order.deliveryArea!.nameAr
                          : order.deliveryArea!.name,
                      color: Colors.green,
                    ),
                  if (order.distanceM != null && order.distanceM != '0')
                    _infoChip(
                      icon: Icons.route_outlined,
                      label: distanceLabelFromString(
                        context,
                        order.distanceM ?? '0',
                      ),
                      color: Colors.orangeAccent,
                    ),
                  if (order.proposalsCount != null && order.proposalsCount! > 0)
                    _infoChip(
                      icon: Icons.payments_outlined,
                      label: '${order.proposalsCount} ${l10n.offers}',
                      color: Colors.redAccent,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: icon == Icons.account_balance_wallet_outlined
            ? color.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              style: AppTextStyles.bold14.copyWith(fontSize: 11, color: color),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── formatDate ────────────────────────────────────────────────────────────────

String formatDate(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
  return DateFormat('MMM dd').format(date);
}
