import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/order_model.dart';
import 'order_budget_chip.dart';
import 'order_route_section.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onViewProposals;
  final VoidCallback onCancel;

  const OrderCard({
    super.key,
    required this.order,
    required this.onViewProposals,
    required this.onCancel,
  });

  Color _statusColor() {
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
    switch (order.status) {
      case 'PENDING':
        return Icons.schedule;
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
    final l10n = AppLocalizations.of(context);
    switch (order.status) {
      case 'PENDING':
        return l10n?.pending ?? 'Pending';
      case 'IN_PROGRESS':
        return l10n?.inProgress ?? 'In Progress';
      case 'DELIVERED':
        return l10n?.delivered ?? 'Delivered';
      case 'CANCELLED':
        return l10n?.cancelled ?? 'Cancelled';
      default:
        return order.status ?? '';
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return l10n.justNow;
    } else if (diff.inMinutes < 60) {
      return l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l10n.hoursAgo(diff.inHours);
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays);
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: AppColors.kSecondaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, statusColor.withOpacity(0.03)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(statusColor, context),
            _buildProductInfo(),
            _buildResultInfo(context),
            if (order.isPending) _buildActionButtons(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color statusColor, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_statusIcon(), color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber ?? 'N/A', style: AppTextStyles.bold16),
                Text(
                  _formatDate(context, order.createdAt ?? DateTime.now()),
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(), size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(context),
                  style: AppTextStyles.bold14.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          // Delivery info or cancellation reason
          if (order.isCancelled && order.cancelledReason != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.reason,
                          style: AppTextStyles.bold14.copyWith(
                            fontSize: 12,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.cancelledReason!,
                          style: AppTextStyles.regular14.copyWith(
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (order.isDelivered && order.deliveredAt != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${AppLocalizations.of(context)!.delivered}: ${_formatDate(context, order.deliveredAt!)}',
                    style: AppTextStyles.medium18.copyWith(
                      fontSize: 13,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container(
              //   padding: const EdgeInsets.all(8),
              //   decoration: BoxDecoration(
              //     color: AppColors.kPrimaryColor.withOpacity(0.08),
              //     borderRadius: BorderRadius.circular(8),
              //   ),
              //   child: const Icon(
              //     Icons.shopping_bag_outlined,
              //     size: 20,
              //     color: AppColors.kPrimaryColor,
              //   ),
              // ),
              // const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.productDescription,
                          style: AppTextStyles.bold14.copyWith(
                            fontSize: 15,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order.status == 'IN_PROGRESS')
                          IconButton(
                            onPressed: onCancel,
                            icon: Icon(
                              Icons.cancel_outlined,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (order.budget != '0.01')
                      OrderBudgetChip(budget: order.budget),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OrderRouteSection(order: order),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onViewProposals,
                  icon: const Icon(Icons.local_offer, size: 18),
                  label: Text(
                    l10n.viewProposals,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                    l10n.cancel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
