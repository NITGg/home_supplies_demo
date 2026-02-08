import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/utils/phone_dialer.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/image_with_fallback.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../core/widgets/text_form.dart';
import '../data/models/orders_model.dart';
import '../manager/orders_cubit.dart';
import '../manager/orders_states.dart';
import 'package:intl/intl.dart';
import 'qr_code_screen.dart';

class ActiveOrderScreen extends StatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final TextEditingController _actualPriceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadActiveOrder();
  }

  void _loadActiveOrder() {
    context.read<OrderCubit>().fetchActiveOrder();
  }

  @override
  void dispose() {
    _actualPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          _loadActiveOrder();
        },
        color: AppColors.kPrimaryColor,
        child: BlocConsumer<OrderCubit, OrderState>(
          listener: (context, state) {
            if (state is ActiveOrderError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is DeliveryCompleted) {
              // Navigate to QR code screen
              context.push('/orders/qr-code', extra: state.qrCode).then((_) {
                // Refresh active order after QR screen
                _loadActiveOrder();
              });
            } else if (state is DeliveryCompleteError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ActiveOrderLoading) {
              return const LoadingScreen(isOne: true,);
            }

            if (state is NoActiveOrder) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Order',
                      style: AppTextStyles.bold16.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You don\'t have any active deliveries',
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is ActiveOrderLoaded) {
              return _buildActiveOrder(context, state.order);
            }

            if (state is CompletingDelivery) {
              return const LoadingScreen(isOne: true);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildActiveOrder(BuildContext context, OrderModel order) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.kPrimaryColor,
                  AppColors.kPrimaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_shipping, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Delivery In Progress',
                  style: AppTextStyles.bold18.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  order.orderNumber,
                  style: AppTextStyles.regular14.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Product Info
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Product Details', style: AppTextStyles.bold16),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImageWithIconFallback(
                        imageUrl: order.productImage,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        iconSize: 40,
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
                          ),
                          const SizedBox(height: 8),
                          _buildInfoChip(
                            'Budget: ${order.budget} EGP',
                            Icons.attach_money,
                          ),
                          const SizedBox(height: 4),
                          _buildInfoChip(
                            'Your Fee: ${order.totalFee} EGP',
                            Icons.payments,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Customer Info
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer', style: AppTextStyles.bold16),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.kSecondaryLightColor,
                      child: order.customer.personalPhoto != null
                          ? ClipOval(
                              child: ImageWithIconFallback(
                                imageUrl: order.customer.personalPhoto,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: AppColors.kPrimaryColor,
                              size: 32,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customer.fullName,
                            style: AppTextStyles.bold16,
                          ),
                          if (order.customer.phone != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              order.customer.phone!,
                              style: AppTextStyles.regular14.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (order.customer.phone != null)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.kPrimaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.white),
                          onPressed: () {
                            openPhoneApp(order.customer.phone??'');
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Delivery Route
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Route', style: AppTextStyles.bold16),
                const SizedBox(height: 16),
                _buildLocationCard(
                  icon: Icons.store,
                  title: 'Pickup',
                  area:
                      '${order.pickupArea.name}${order.pickupArea.governorate != null ? ", ${order.pickupArea.governorate!.name}" : ""}',
                  address: order.pickupAddressDescription,
                  isPrimary: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 32),
                      Column(
                        children: List.generate(
                          3,
                          (index) => Container(
                            width: 2,
                            height: 6,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: AppColors.kPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildLocationCard(
                  icon: Icons.location_on,
                  title: 'Delivery',
                  area:
                      '${order.deliveryArea.name}${order.deliveryArea.governorate != null ? ", ${order.deliveryArea.governorate!.name}" : ""}',
                  address: order.deliveryAddressDescription,
                  isPrimary: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Order Timeline
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timeline', style: AppTextStyles.bold16),
                const SizedBox(height: 12),
                _buildTimelineItem(
                  'Order Created',
                  DateFormat('MMM dd, hh:mm a').format(order.createdAt),
                  true,
                ),
                if (order.offerAcceptedAt != null)
                  _buildTimelineItem(
                    'Offer Accepted',
                    DateFormat(
                      'MMM dd, hh:mm a',
                    ).format(order.offerAcceptedAt!),
                    true,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Complete Delivery Section
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Complete Delivery', style: AppTextStyles.bold16),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the actual product price to generate QR code for customer confirmation',
                    style: AppTextStyles.regular14.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextFormField(
                    label: 'Actual Product Price (EGP)',
                    controller: _actualPriceController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.shopping_cart),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the actual product price';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  AppCustomButton(
                    onPressed: _completeDelivery,
                    text: 'Generate QR Code',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.kSecondaryLightColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.kSecondaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.regular14.copyWith(
              fontSize: 12,
              color: AppColors.kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String title,
    required String area,
    required String address,
    required bool isPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.kSecondaryLightColor
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? AppColors.kPrimaryColor : Colors.green.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isPrimary ? AppColors.kPrimaryColor : Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bold14.copyWith(
                    color: isPrimary
                        ? AppColors.kSecondaryColor
                        : Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  area,
                  style: AppTextStyles.regular14.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String time, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.kPrimaryColor
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bold14),
                Text(
                  time,
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _completeDelivery() {
    if (_formKey.currentState!.validate()) {
      final actualPrice = double.parse(_actualPriceController.text);
      context.read<OrderCubit>().completeDelivery(
        orderId:
            (context.read<OrderCubit>().state as ActiveOrderLoaded).order.id,
        actualPrice: actualPrice,
      );
    }
  }
}
