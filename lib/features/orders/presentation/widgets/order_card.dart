import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/widgets/image_with_fallback.dart';
import '../../data/models/orders_model.dart';

class OrderCardWidget extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCardWidget({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with order number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: AppTextStyles.bold16.copyWith(
                        color: AppColors.kPrimaryColor,
                      ),
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 12),

              // Product info with image
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageWithIconFallback(
                      imageUrl: order.productImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      iconSize: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productDescription,
                          style: AppTextStyles.bold14,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Budget: ${order.budget} EGP',
                          style: AppTextStyles.regular14.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 8),

              // Pickup location
              _buildLocationRow(
                icon: Icons.store,
                label: 'Pickup',
                location: order.pickupArea.name,
                address: order.pickupAddressDescription,
              ),
              const SizedBox(height: 8),

              // Delivery location
              _buildLocationRow(
                icon: Icons.location_on,
                label: 'Delivery',
                location: order.deliveryArea.name,
                address: order.deliveryAddressDescription,
              ),
              const SizedBox(height: 12),

              // Footer info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.customer.fullName,
                        style: AppTextStyles.regular14.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(order.createdAt),
                    style: AppTextStyles.regular14.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String displayText;

    switch (status) {
      case 'PENDING':
        bgColor = AppColors.kSecondaryLightColor;
        textColor = AppColors.kSecondaryColor;
        displayText = 'Pending';
        break;
      case 'IN_PROGRESS':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        displayText = 'In Progress';
        break;
      case 'DELIVERED':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        displayText = 'Delivered';
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: AppTextStyles.bold14.copyWith(
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String location,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.kPrimaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: $location',
                style: AppTextStyles.bold14.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: AppTextStyles.regular14.copyWith(
                  fontSize: 12,
                  color: Colors.grey.shade600,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }
}