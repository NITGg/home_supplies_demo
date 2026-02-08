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

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final TextEditingController _feeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  FeeRangeModel? _feeRange;

  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().fetchOrderDetails(
      widget.orderId,
      fetchFeeRange: true,
    );
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.kSecondaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Order Details',
          style: AppTextStyles.bold18.copyWith(
            color: AppColors.kSecondaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<OrderCubit, OrderState>(
        listener: (context, state) {
          if (state is OrderDetailsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is OfferSubmitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offer submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
            // Refresh available orders
            context.read<OrderCubit>().fetchAvailableOrders();
          } else if (state is OfferSubmitError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is OrderDetailsLoading) {
            return const LoadingScreen(isOne: true);
          }

          if (state is OrderDetailsLoaded) {
            _feeRange = state.feeRange;
            return _buildOrderDetails(context, state.order);
          }

          if (state is SubmittingOffer) {
            return const LoadingScreen(isOne: true);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildOrderDetails(BuildContext context, OrderModel order) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image and Info
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ImageWithIconFallback(
                      imageUrl: order.productImage,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      iconSize: 60,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  order.orderNumber,
                  style: AppTextStyles.bold16.copyWith(
                    color: AppColors.kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(order.productDescription, style: AppTextStyles.medium18),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 20,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Customer Budget: ',
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${order.budget} EGP',
                      style: AppTextStyles.bold16.copyWith(
                        color: AppColors.kPrimaryColor,
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
                Text('Customer Information', style: AppTextStyles.bold16),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.kSecondaryLightColor,
                      child: order.customer.personalPhoto != null
                          ? ClipOval(
                              child: ImageWithIconFallback(
                                imageUrl: order.customer.personalPhoto,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: AppColors.kPrimaryColor,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customer.fullName,
                            style: AppTextStyles.bold14,
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
                      IconButton(
                        icon: const Icon(
                          Icons.phone,
                          color: AppColors.kPrimaryColor,
                        ),
                        onPressed: () {
                          openPhoneApp(order.customer.phone??'');
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Location Details
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Route', style: AppTextStyles.bold16),
                const SizedBox(height: 16),
                _buildLocationDetail(
                  icon: Icons.store,
                  title: 'Pickup Location',
                  area:
                      '${order.pickupArea.name}, ${order.pickupArea.governorate?.name ?? ""}',
                  address: order.pickupAddressDescription,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      Container(
                        width: 2,
                        height: 30,
                        color: AppColors.kPrimaryColor,
                      ),
                    ],
                  ),
                ),
                _buildLocationDetail(
                  icon: Icons.location_on,
                  title: 'Delivery Location',
                  area:
                      '${order.deliveryArea.name}, ${order.deliveryArea.governorate?.name ?? ""}',
                  address: order.deliveryAddressDescription,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Order Info
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Information', style: AppTextStyles.bold16),
                const SizedBox(height: 12),
                _buildInfoRow('Payment Method', order.paymentMethod),
                _buildInfoRow('Status', order.status),
                _buildInfoRow(
                  'Created',
                  DateFormat('MMM dd, yyyy - hh:mm a').format(order.createdAt),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Submit Offer Section
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submit Your Offer', style: AppTextStyles.bold16),
                  const SizedBox(height: 12),
                  if (_feeRange != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.kSecondaryLightColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.kPrimaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Fee range: ${_feeRange!.minDeliveryFee.toStringAsFixed(0)} - ${_feeRange!.maxDeliveryFee.toStringAsFixed(0)} EGP',
                              style: AppTextStyles.regular14.copyWith(
                                color: AppColors.kSecondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppTextFormField(
                    label: 'Your Delivery Fee (EGP)',
                    controller: _feeController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.attach_money),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your delivery fee';
                      }
                      final fee = double.tryParse(value);
                      if (fee == null) {
                        return 'Please enter a valid number';
                      }
                      if (_feeRange != null) {
                        if (fee < _feeRange!.minDeliveryFee ||
                            fee > _feeRange!.maxDeliveryFee) {
                          return 'Fee must be between ${_feeRange!.minDeliveryFee.toStringAsFixed(0)} and ${_feeRange!.maxDeliveryFee.toStringAsFixed(0)} EGP';
                        }
                      }
                      return null;
                    },
                  ),
                  AppCustomButton(
                    onPressed: _submitOffer,
                    text: 'Submit Offer',
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

  Widget _buildLocationDetail({
    required IconData icon,
    required String title,
    required String area,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.kSecondaryLightColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.kPrimaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bold14),
              const SizedBox(height: 4),
              Text(
                area,
                style: AppTextStyles.regular14.copyWith(
                  color: AppColors.kSecondaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: AppTextStyles.regular14.copyWith(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.regular14.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Text(value, style: AppTextStyles.bold14),
        ],
      ),
    );
  }

  void _submitOffer() async {
    if (_formKey.currentState!.validate()) {
      // Double-check for active order before submitting
      final hasActiveOrder = await context.read<OrderCubit>().hasActiveOrder();

      if (hasActiveOrder) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an active order. Please complete it first.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final fee = double.parse(_feeController.text);
      if (mounted) {
        context.read<OrderCubit>().submitOffer(
          orderId: widget.orderId,
          totalFee: fee,
        );
      }
    }
  }
}
