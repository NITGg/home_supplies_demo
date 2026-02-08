import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/order_card.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../manager/orders_cubit.dart';
import '../manager/orders_states.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    context.read<OrderCubit>().fetchAvailableOrders();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: BlocConsumer<OrderCubit, OrderState>(
        listener: (context, state) {
          if (state is AvailableOrdersError) {
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
            // Mark the order as offered in the UI
            context.read<OrderCubit>().markOrderAsOffered(state.orderId);

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
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AvailableOrdersLoading) {
            return const LoadingScreen(isOne: true);
          }

          if (state is AvailableOrdersLoaded) {
            if (state.orders.isEmpty) {
              return _buildEmptyState(context);
            }

            return RefreshIndicator(
              onRefresh: _loadOrders,
              color: AppColors.kPrimaryColor,
              child: Column(
                children: [
                  // Header with stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.availableOrders,
                                      style: AppTextStyles.bold18.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      l10n.ordersCount(state.orders.length),
                                      style: AppTextStyles.regular14.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Orders list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.orders.length,
                      itemBuilder: (context, index) {
                        final order = state.orders[index];
                        return OrderCardWidget(
                          order: order,
                          onTap: () async {
                            final result = await context.push(
                              '/orders/details',
                              extra: order.id,
                            );

                            // Refresh orders if returned from details
                            if (result == true) {
                              _loadOrders();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.kPrimaryColor,
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
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
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: AppColors.kPrimaryColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.noAvailableOrders,
                    style: AppTextStyles.bold18.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.checkBackLater,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _loadOrders,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.refresh),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.kPrimaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}