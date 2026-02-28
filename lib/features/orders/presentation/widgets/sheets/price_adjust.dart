import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/core/style/text_styles.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';
import '../../../data/models/order_model.dart';
import '../../../manager/order_cubit.dart';
import '../../../manager/order_states.dart';

/// Un-dismissible bottom sheet shown when the courier proposes a new price.
/// The user MUST accept or reject — they cannot dismiss it by tapping outside
/// or pressing the back button.
class PriceAdjustmentSheet extends StatelessWidget {
  final int orderId;
  final double newPrice;
  final double? originalPrice;
  final Order? order;

  const PriceAdjustmentSheet({
    super.key,
    required this.orderId,
    required this.newPrice,
    this.originalPrice,
    this.order,
  });

  /// Call this from _handleNewPrice in OrdersListScreen.
  /// Looks up the order from the cubit state automatically.
  static Future<void> show(
      BuildContext context, {
        required int orderId,
        required double newPrice,
        double? originalPrice,
      }) {
    // Try to find the order in the currently loaded state
    Order? order;
    final state = context.read<OrderCubit>().state;
    if (state is OrdersLoaded) {
      try {
        order = state.orders.firstWhere((o) => o.id == orderId);
      } catch (_) {
        order = null;
      }
    }

    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<OrderCubit>(),
        child: PriceAdjustmentSheet(
          orderId: orderId,
          newPrice: newPrice,
          originalPrice: originalPrice,
          order: order,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BlocConsumer<OrderCubit, OrderState>(
          listenWhen: (_, current) =>
          current is PriceAdjustmentResponded || current is OrderError,
          listener: (context, state) {
            if (state is PriceAdjustmentResponded || state is OrderError) {
              Navigator.of(context).pop();
            }
          },
          buildWhen: (_, current) =>
          current is PriceAdjustmentResponding ||
              current is PriceAdjustmentResponded ||
              current is OrderError,
          builder: (context, state) {
            final isLoading = state is PriceAdjustmentResponding;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Drag handle ──
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── Icon ──
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.price_change_outlined,
                    size: 36,
                    color: AppColors.kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Title ──
                Text(
                  l10n.budgetNotEnough,
                  style: AppTextStyles.bold16.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // ── Subtitle ──
                Text(
                  l10n.actualPriceIsHigher,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                // ── Order info card ──
                if (order != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.kPrimaryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.kPrimaryColor.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image or fallback
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: order!.productImage != null &&
                              order!.productImage!.isNotEmpty
                              ? Image.network(
                            order!.productImage!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const _FallbackProductIcon(),
                          )
                              : const _FallbackProductIcon(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order number
                              Text(
                                '#${order!.id}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Product description
                              if (order!.productDescription != null &&
                                  order!.productDescription!.isNotEmpty)
                                Text(
                                  order!.productDescription!,
                                  style: AppTextStyles.bold16
                                      .copyWith(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              // Pickup → Delivery addresses
                              if (order!.pickupAddressDescription != null ||
                                  order!.deliveryAddressDescription !=
                                      null) ...[
                                const SizedBox(height: 6),
                                _AddressRow(
                                  icon: Icons.radio_button_checked,
                                  iconColor: Colors.green.shade600,
                                  text:
                                  order!.pickupAddressDescription ?? '',
                                ),
                                const SizedBox(height: 3),
                                _AddressRow(
                                  icon: Icons.location_on,
                                  iconColor: Colors.red.shade400,
                                  text: order!.deliveryAddressDescription ??
                                      '',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Price card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      if (originalPrice != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.budget,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              '${originalPrice!.toStringAsFixed(2)} ${l10n.egp}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.newBudget,
                            style:
                            AppTextStyles.bold16.copyWith(fontSize: 15),
                          ),
                          Text(
                            '${newPrice.toStringAsFixed(2)} ${l10n.egp}',
                            style: AppTextStyles.bold16.copyWith(
                              fontSize: 18,
                              color: AppColors.kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Action buttons ──
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.kPrimaryColor,
                    ),
                  )
                else
                  Row(
                    children: [
                      // REJECT
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respond(context, 'REJECTED'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(
                              color: Colors.red.shade300,
                              width: 1.5,
                            ),
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close,
                                  size: 18, color: Colors.red.shade600),
                              const SizedBox(width: 6),
                              Text(
                                l10n.reject,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ACCEPT
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _respond(context, 'ACCEPTED'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                l10n.accept,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _respond(BuildContext context, String status) {
    context.read<OrderCubit>().respondToPriceAdjustment(
      orderId: orderId,
      status: status,
    );
  }
}

// ── Small reusable address row ────────────────────────────────────────────────

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Fallback icon when there's no product image ───────────────────────────────

class _FallbackProductIcon extends StatelessWidget {
  const _FallbackProductIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 28,
        color: Colors.grey.shade400,
      ),
    );
  }
}