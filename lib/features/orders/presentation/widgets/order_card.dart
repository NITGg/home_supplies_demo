import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/orders_model.dart';

class OrderCardWidget extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCardWidget({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: AppColors.kPrimaryColor.withOpacity(0.1),
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
              colors: [
                Colors.white,
                AppColors.kSecondaryLightColor.withOpacity(0.1),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, l10n),
                const SizedBox(height: 16),
                _buildProductInfo(context, l10n),
                const SizedBox(height: 16),
                _buildDeliveryRoute(context, l10n),
                const SizedBox(height: 12),
                _buildFooter(context, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.kPrimaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: AppTextStyles.bold16.copyWith(
                        color: AppColors.kPrimaryColor,
                      ),
                    ),
                    Text(
                      _formatDate(context, order.createdAt),
                      style: AppTextStyles.regular14.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(context, order.status, order.hasMyProposal),
      ],
    );
  }

  Widget _buildProductInfo(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'order-image-${order.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ImageWithIconFallback(
                  imageUrl: order.productImage,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  iconSize: 35,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.kSecondaryColor.withOpacity(0.1),
                        AppColors.kSecondaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.kSecondaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 16,
                        color: AppColors.kSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${l10n.budget}: ${order.budget} ${l10n.egp}',
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 13,
                          color: AppColors.kSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryRoute(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kSecondaryLightColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildLocationRow(
            context: context,
            icon: Icons.store_outlined,
            label: l10n.pickup,
            location: order.pickupArea.name,
            address: order.pickupAddressDescription,
            color: AppColors.kPrimaryColor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 20),
                ...List.generate(
                  3,
                  (index) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.kPrimaryColor.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.kPrimaryColor.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.kPrimaryColor.withOpacity(0.6),
                ),
              ],
            ),
          ),
          _buildLocationRow(
            context: context,
            icon: Icons.location_on_outlined,
            label: l10n.delivery,
            location: order.deliveryArea.name,
            address: order.deliveryAddressDescription,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.kSecondaryLightColor,
                child: Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.kPrimaryColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.customer.fullName,
                  style: AppTextStyles.medium18.copyWith(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (order.proposalsCount != null && order.proposalsCount! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade200, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_offer,
                  size: 12,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  '${order.proposalsCount} ${l10n.offers}',
                  style: AppTextStyles.bold14.copyWith(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    String status,
    bool? hasMyProposal,
  ) {
    final l10n = AppLocalizations.of(context)!;

    // Show "Offer Submitted" if user has submitted an offer
    if (hasMyProposal == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              l10n.offerSubmitted,
              style: AppTextStyles.bold14.copyWith(
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    Color bgColor;
    Color textColor;
    String displayText;
    IconData icon;

    switch (status) {
      case 'PENDING':
        bgColor = AppColors.kSecondaryLightColor;
        textColor = AppColors.kSecondaryColor;
        displayText = l10n.pending;
        icon = Icons.schedule;
        break;
      case 'IN_PROGRESS':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        displayText = l10n.inProgress;
        icon = Icons.local_shipping;
        break;
      case 'DELIVERED':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        displayText = l10n.delivered;
        icon = Icons.check_circle;
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        displayText = status;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: AppTextStyles.bold14.copyWith(
              fontSize: 11,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String location,
    required String address,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: $location',
                style: AppTextStyles.bold14.copyWith(
                  fontSize: 13,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: AppTextStyles.regular14.copyWith(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
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
}
