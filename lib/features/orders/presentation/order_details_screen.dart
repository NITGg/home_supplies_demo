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
import '../../../l10n/app_localizations.dart';
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
  bool _isSubmitting = false;

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
    final l10n = AppLocalizations.of(context)!;

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
          l10n.orderDetails,
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
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else if (state is OfferSubmitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.offerSubmittedSuccessfully)),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );

            // Return true to signal refresh needed
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                context.pop(true);
              }
            });
          } else if (state is OfferSubmitError) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else if (state is SubmittingOffer) {
            setState(() => _isSubmitting = true);
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
    final l10n = AppLocalizations.of(context)!;

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
                  child: Hero(
                    tag: 'order-image-${order.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.kPrimaryColor.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ImageWithIconFallback(
                          imageUrl: order.productImage,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          iconSize: 70,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.orderNumber,
                    style: AppTextStyles.bold14.copyWith(
                      color: AppColors.kPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  order.productDescription,
                  style: AppTextStyles.bold18.copyWith(
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.kSecondaryColor.withOpacity(0.1),
                        AppColors.kSecondaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.kSecondaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: AppColors.kSecondaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.customerBudget,
                              style: AppTextStyles.regular14.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.budget} ${l10n.egp}',
                              style: AppTextStyles.bold25.copyWith(
                                fontSize: 20,
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
                Text(l10n.customerInformation, style: AppTextStyles.bold16),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.kSecondaryLightColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
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
                          size: 30,
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
                            gradient: LinearGradient(
                              colors: [
                                AppColors.kPrimaryColor,
                                AppColors.kPrimaryColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.phone, color: Colors.white),
                            onPressed: () {
                              openPhoneApp(order.customer.phone ?? '');
                            },
                          ),
                        ),
                    ],
                  ),
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
                Text(l10n.deliveryRoute, style: AppTextStyles.bold16),
                const SizedBox(height: 16),
                _buildLocationDetail(
                  context: context,
                  icon: Icons.store_outlined,
                  title: l10n.pickupLocation,
                  area:
                  '${order.pickupArea.name}, ${order.pickupArea.governorate?.name ?? ""}',
                  address: order.pickupAddressDescription,
                  color: AppColors.kPrimaryColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 28),
                      Column(
                        children: List.generate(
                          4,
                              (index) => Container(
                            width: 2,
                            height: 6,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.kPrimaryColor.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.kPrimaryColor.withOpacity(0.3),
                                Colors.green.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
                _buildLocationDetail(
                  context:context,
                  icon: Icons.location_on_outlined,
                  title: l10n.deliveryLocation,
                  area:
                  '${order.deliveryArea.name}, ${order.deliveryArea.governorate?.name ?? ""}',
                  address: order.deliveryAddressDescription,
                  color: Colors.green,
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
                Text(l10n.orderInformation, style: AppTextStyles.bold16),
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  l10n.paymentMethod,
                  order.paymentMethod,
                  Icons.payment,
                ),
                _buildInfoRow(
                  context,
                  l10n.status,
                  _getStatusText(context, order.status),
                  Icons.info_outline,
                ),
                _buildInfoRow(
                  context,
                  l10n.created,
                  DateFormat('MMM dd, yyyy - hh:mm a').format(order.createdAt),
                  Icons.calendar_today,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Submit Offer Section (only if user hasn't submitted an offer yet)
          if (order.hasMyProposal != true)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    AppColors.kSecondaryLightColor.withOpacity(0.2),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.kPrimaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_offer,
                            color: AppColors.kPrimaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(l10n.submitYourOffer, style: AppTextStyles.bold18),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_feeRange != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.kSecondaryLightColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.kPrimaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.kPrimaryColor,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.allowedFeeRange,
                                    style: AppTextStyles.bold14.copyWith(
                                      color: AppColors.kSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_feeRange!.minDeliveryFee.toStringAsFixed(0)} - ${_feeRange!.maxDeliveryFee.toStringAsFixed(0)} ${l10n.egp}',
                                    style: AppTextStyles.bold16.copyWith(
                                      color: AppColors.kPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AppTextFormField(
                      label: l10n.yourDeliveryFee,
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.attach_money),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.pleaseEnterDeliveryFee;
                        }
                        final fee = double.tryParse(value);
                        if (fee == null) {
                          return l10n.pleaseEnterValidNumber;
                        }
                        if (_feeRange != null) {
                          if (fee < _feeRange!.minDeliveryFee ||
                              fee > _feeRange!.maxDeliveryFee) {
                            return l10n.feeMustBeBetween(
                              _feeRange!.minDeliveryFee.toStringAsFixed(0),
                              _feeRange!.maxDeliveryFee.toStringAsFixed(0),
                            );
                          }
                        }
                        return null;
                      },
                    ),
                    AppCustomButton(
                      onPressed:  _submitOffer,
                      text: _isSubmitting ? l10n.submitting : l10n.submitOffer,
                      isLoading: _isSubmitting,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade50,
                    Colors.green.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.offerAlreadySubmitted,
                    style: AppTextStyles.bold18.copyWith(
                      color: Colors.green.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.waitingForCustomerResponse,
                    style: AppTextStyles.regular14.copyWith(
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLocationDetail({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String area,
    required String address,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bold14.copyWith(
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  area,
                  style: AppTextStyles.medium18.copyWith(
                    color: AppColors.kSecondaryColor,
                    fontSize: 14
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.kSecondaryLightColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.kPrimaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bold14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'PENDING':
        return l10n.pending;
      case 'IN_PROGRESS':
        return l10n.inProgress;
      case 'DELIVERED':
        return l10n.delivered;
      default:
        return status;
    }
  }

  void _submitOffer() async {
    if (_formKey.currentState!.validate()) {
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