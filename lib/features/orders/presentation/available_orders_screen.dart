import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/order_card.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/orders_shimmers.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../manager/orders_cubit.dart';
import '../manager/orders_states.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  final ScrollController _scrollController = ScrollController();

  Future<void> reload() async {
    await context.read<OrderCubit>().fetchAvailableOrders(refresh: true);
  }

  @override
  void initState() {
    super.initState();
    reload();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      // Load more when 90% scrolled
      context.read<OrderCubit>().loadMoreAvailableOrders();
    }
  }

  Future<void> _loadOrders() async {
    await context.read<OrderCubit>().fetchAvailableOrders(refresh: true);
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
          // Initial loading
          if (state is AvailableOrdersLoading && !state.isLoadingMore) {
            return OrderShimmers.availableOrdersListShimmer();
          }

          if (state is AvailableOrdersLoaded) {
            if (state.orders.isEmpty) {
              return _buildEmptyState(context);
            }

            return RefreshIndicator(
              onRefresh: _loadOrders,
              color: AppColors.kPrimaryColor,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.orders.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.orders.length) {
                    // Load more indicator
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final order = state.orders[index];
                  return OrderCardWidget(
                    order: order,
                    onTap: () async {
                      // Navigate and only refresh if offer was submitted
                      final result = await context.push(
                        '/orders/details',
                        extra: order.id,
                      );

                      if (result == true && mounted) {
                        _loadOrders();
                      }
                    },
                  );
                },
              ),
            );
          }

          // Handle error state with empty list
          if (state is AvailableOrdersError) {
            return _buildEmptyState(context, isError: true);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool isError = false}) {
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
                      isError
                          ? Icons.error_outline
                          : Icons.shopping_bag_outlined,
                      size: 80,
                      color: AppColors.kPrimaryColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isError ? l10n.error : l10n.noAvailableOrders,
                    style: AppTextStyles.bold18.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      isError ? l10n.retry : l10n.checkBackLater,
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
