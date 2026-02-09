import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/orders_shimmers.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/utils/biometric_auth_service.dart';
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
import 'widgets/order_bottom_sheets.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          _loadActiveOrder();
        },
        color: AppColors.kPrimaryColor,
        child: BlocConsumer<OrderCubit, OrderState>(
          listener: (context, state) {
            _handleStateChanges(context, state, l10n);
          },
          builder: (context, state) {
            if (state is ActiveOrderLoading) {
              return OrderShimmers.activeOrderShimmer();
            }

            if (state is NoActiveOrder) {
              return _buildNoActiveOrderState(l10n);
            }

            if (state is ActiveOrderLoaded) {
              return _buildActiveOrder(context, state.order);
            }

            if (state is CompletingDelivery) {
              return const LoadingScreen(isOne: true);
            }

            if (state is ActiveOrderError && state.order != null) {
              return _buildActiveOrder(context, state.order!);
            }

            if (state is DeliveryCompleteError && state.order != null) {
              return _buildActiveOrder(context, state.order!);
            }

            if (state is HighPriceReportError && state.order != null) {
              return _buildActiveOrder(context, state.order!);
            }

            if (state is OrderCancelError && state.order != null) {
              return _buildActiveOrder(context, state.order!);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _handleStateChanges(
    BuildContext context,
    OrderState state,
    AppLocalizations l10n,
  ) {
    // Handle order cancellation - navigation handled by bottom sheet
    if (state is OrderCancelled) {
      _showSuccessSnackBar(context, l10n.orderCancelled, Colors.orange);
    }

    // Handle high price report - reload handled by bottom sheet
    if (state is HighPriceReported) {
      _showSuccessSnackBar(context, l10n.done, Colors.green);
      _loadActiveOrder();
    }

    // Handle active order errors
    if (state is ActiveOrderError) {
      _showErrorSnackBar(context, state.message);
    }

    // Handle delivery completion
    if (state is DeliveryCompleted) {
      context.push('/orders/qr-code', extra: state.qrCode).then((_) {
        _loadActiveOrder();
      });
    } else if (state is DeliveryCompleteError) {
      _showErrorSnackBar(context, state.message);
    }
  }

  void _showSuccessSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildNoActiveOrderState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.kSecondaryLightColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.work_outline,
              size: 80,
              color: AppColors.kPrimaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noActiveOrder,
            style: AppTextStyles.bold18.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.noActiveDeliveries,
              textAlign: TextAlign.center,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrder(BuildContext context, OrderModel order) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Banner
          _buildStatusBanner(l10n, order),

          const SizedBox(height: 12),

          // Product Info
          _buildProductInfo(context, l10n, order),

          const SizedBox(height: 12),

          // Customer Info
          _buildCustomerInfo(context, l10n, order),

          const SizedBox(height: 12),

          // Delivery Route
          _buildDeliveryRoute(context, l10n, order),

          const SizedBox(height: 12),

          // Order Timeline
          _buildOrderTimeline(context, l10n, order),

          const SizedBox(height: 12),

          // Cancel Order Section
          _buildCancelOrderSection(context, l10n, order),

          const SizedBox(height: 12),

          // Report budget not enough
          _buildReportBudgetSection(context, l10n, order),

          const SizedBox(height: 12),

          // Complete Delivery Section
          _buildCompleteDeliverySection(context, l10n, order),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(AppLocalizations l10n, OrderModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.kPrimaryColor,
            AppColors.kSecondaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.deliveryInProgress,
              style: AppTextStyles.bold25.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.orderNumber,
                style: AppTextStyles.medium18.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(
    BuildContext context,
    AppLocalizations l10n,
    OrderModel order,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.productDetails, style: AppTextStyles.bold16),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    iconSize: 40,
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
                      style: AppTextStyles.bold14,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoChip(
                      context,
                      '${l10n.budget}: ${order.budget} ${l10n.egp}',
                      Icons.account_balance_wallet,
                    ),
                    const SizedBox(height: 4),
                    _buildInfoChip(
                      context,
                      '${l10n.totalFee}: ${order.totalFee} ${l10n.egp}',
                      Icons.payments_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(
    BuildContext context,
    AppLocalizations l10n,
    OrderModel order,
  ) {
    return order.customer == null
        ? SizedBox.shrink()
        : Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.customer, style: AppTextStyles.bold16),
                const SizedBox(height: 12),
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
                        child: order.customer?.personalPhoto != null
                            ? ClipOval(
                                child: ImageWithIconFallback(
                                  imageUrl: order.customer?.personalPhoto,
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
                              order.customer!.fullName,
                              style: AppTextStyles.bold16,
                            ),
                            if (order.customer?.phone != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                textDirection: ui.TextDirection.ltr,
                                order.customer!.phone!,
                                style: AppTextStyles.regular14.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (order.customer?.phone != null)
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
                              openPhoneApp(order.customer?.phone ?? '');
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildDeliveryRoute(
    BuildContext context,
    AppLocalizations l10n,
    OrderModel order,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deliveryRoute, style: AppTextStyles.bold16),
          const SizedBox(height: 16),
          _buildLocationCard(
            icon: Icons.store_outlined,
            title: l10n.pickup,
            area:
                '${order.pickupArea?.name}${order.pickupArea?.governorate != null ? ", ${order.pickupArea?.governorate!.name}" : ""}',
            address: order.pickupAddressDescription,
            isPrimary: true,
            context: context,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                      color: AppColors.kPrimaryColor.withOpacity(0.4),
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
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
          _buildLocationCard(
            context: context,
            icon: Icons.location_on_outlined,
            title: l10n.delivery,
            area:
                '${order.deliveryArea?.name}${order.deliveryArea?.governorate != null ? ", ${order.deliveryArea?.governorate!.name}" : ""}',
            address: order.deliveryAddressDescription,
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTimeline(
    BuildContext context,
    AppLocalizations l10n,
    OrderModel order,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timeline, style: AppTextStyles.bold16),
          const SizedBox(height: 12),
          _buildTimelineItem(
            context,
            l10n.orderCreated,
            DateFormat('MMM dd, hh:mm a').format(order.createdAt),
            true,
          ),
          if (order.offerAcceptedAt != null)
            _buildTimelineItem(
              context,
              l10n.offerAccepted,
              DateFormat('MMM dd, hh:mm a').format(order.offerAcceptedAt!),
              true,
            ),
        ],
      ),
    );
  }

  Widget _buildCancelOrderSection(
    BuildContext context,
    AppLocalizations l10n,
    OrderModel order,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Text(l10n.cancelOrder, style: AppTextStyles.bold16),
            ],
          ),
          const SizedBox(height: 12),
          AppCustomButton(
            onPressed: () =>
                _showCancelDialog(context, order, isUnavailable: true),
            text: l10n.productUnAvailable,
            isSecondary: true,
          ),
          const SizedBox(height: 8),
          AppCustomButton(
            onPressed: () =>
                _showCancelDialog(context, order, isUnavailable: false),
            text: l10n.otherReason,
            isDelete: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReportBudgetSection(
    BuildContext context,
    AppLocalizations l10n,
    OrderModel order,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.price_change, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(l10n.budgetNotEnough, style: AppTextStyles.bold16),
            ],
          ),
          const SizedBox(height: 12),
          AppCustomButton(
            onPressed: () => _showReportHighPriceDialog(context, order),
            text: l10n.askCustomer,
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteDeliverySection(
    BuildContext context,
    AppLocalizations l10n,
    OrderModel order,
  ) {
    return Container(
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
                    Icons.qr_code_2,
                    color: AppColors.kPrimaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(l10n.completeDelivery, style: AppTextStyles.bold18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.enterActualPriceMessage,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            AppTextFormField(
              label: l10n.actualProductPrice,
              controller: _actualPriceController,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.shopping_cart),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterActualPrice;
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return l10n.pleaseEnterValidPrice;
                }
                return null;
              },
            ),
            AppCustomButton(
              onPressed: () => _completeDelivery(order),
              text: l10n.generateQrCode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String text, IconData icon) {
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
    required BuildContext context,
    required IconData icon,
    required String title,
    required String area,
    required String address,
    required bool isPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.kSecondaryLightColor.withOpacity(0.3)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? AppColors.kPrimaryColor.withOpacity(0.3)
              : Colors.green.shade300,
          width: 1.5,
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
                  style: AppTextStyles.medium18.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
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

  Widget _buildTimelineItem(
    BuildContext context,
    String title,
    String time,
    bool isCompleted,
  ) {
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
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: isCompleted
                  ? [
                      BoxShadow(
                        color: AppColors.kPrimaryColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
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

  Future<void> _completeDelivery(OrderModel order) async {
    if (_formKey.currentState!.validate()) {
      final success = await BiometricManager().verifyBiometric(
        context: context,
      );
      if (!success) return;
      final actualPrice = double.parse(_actualPriceController.text);
      if (context.mounted) {
        context.read<OrderCubit>().completeDelivery(
          orderId: order.id,
          actualPrice: actualPrice,
        );
      }
    }
  }

  Future<void> _showCancelDialog(
    BuildContext context,
    OrderModel order, {
    required bool isUnavailable,
  }) async {
    final result = await showCancelOrderSheet(
      context: context,
      isUnavailable: isUnavailable,
      orderId: order.id,
    );

    // The bottom sheet handles the state and automatically closes
    // We don't need to do anything here as the listener handles navigation
  }

  Future<void> _showReportHighPriceDialog(
    BuildContext context,
    OrderModel order,
  ) async {
    final result = await showReportHighPriceSheet(
      context: context,
      budgetAmount: order.budget,
      orderId: order.id,
    );

    // The bottom sheet handles the state and automatically closes
    // We don't need to do anything here as the listener handles reload
  }
}
