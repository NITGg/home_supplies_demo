import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/orders_shimmers.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../manager/orders_cubit.dart';
import '../manager/orders_states.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
      context.read<OrderCubit>().loadMoreHistory();
    }
  }

  Future<void> _loadHistory({String? filter}) async {
    final filterToUse = filter ?? _currentFilter;
    setState(() {
      _currentFilter = filterToUse;
    });
    await context.read<OrderCubit>().fetchOrderHistory(
      refresh: true,
      filter: filterToUse,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(context),

          // Orders list
          Expanded(
            child: BlocConsumer<OrderCubit, OrderState>(
              buildWhen: (previous, current) {
                // Only rebuild when orders change
                return current is OrderHistoryLoaded || current is OrderHistoryError;
              },
              listener: (context, state) {
                if (state is OrderHistoryError) {
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
                }
              },
              builder: (context, state) {
                // Initial loading
                if (state is OrderHistoryLoading && !state.isLoadingMore) {
                  return OrderShimmers.orderHistoryListShimmer();
                }

                if (state is OrderHistoryLoaded) {
                  if (state.orders.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return RefreshIndicator(
                    onRefresh: () => _loadHistory(),
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
                        return _buildHistoryOrderCard(context, order);
                      },
                    ),
                  );
                }

                // Handle error state with empty list
                if (state is OrderHistoryError) {
                  return _buildEmptyState(context, isError: true);
                }

                // Initial state - trigger load
                if (state is OrderHistoryInitial) {
                  // This will trigger the load in initState
                  return OrderShimmers.orderHistoryListShimmer();
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              l10n.filterBy,
              style: AppTextStyles.medium18.copyWith(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            _buildFilterChip(
              label: l10n.all,
              value: 'all',
              icon: Icons.all_inclusive,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: l10n.delivered,
              value: 'completed',
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: l10n.cancelled,
              value: 'cancelled',
              icon: Icons.cancel_outlined,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final isSelected = _currentFilter == value;
    final chipColor = color ?? AppColors.kPrimaryColor;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: isSelected ? Colors.white : chipColor),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _loadHistory(filter: value);
        }
      },
      selectedColor: chipColor,
      backgroundColor: chipColor.withOpacity(0.1),
      labelStyle: AppTextStyles.bold14.copyWith(
        fontSize: 10,
        color: isSelected ? Colors.white : chipColor,
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? chipColor : chipColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildHistoryOrderCard(BuildContext context, order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: AppColors.kPrimaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to order details (read-only for history)
          context.push('/orders/details', extra: order.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                order.isCancelled
                    ? Colors.red.shade50.withOpacity(0.3)
                    : order.isDelivered
                    ? Colors.green.shade50.withOpacity(0.3)
                    : Colors.grey.shade50.withOpacity(0.3),
              ],
            ),
          ),
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
                                if (order.totalFee != null)
                                  Text(
                                    '${order.totalFee} ${AppLocalizations.of(context)!.egp}',
                                    style: AppTextStyles.medium18.copyWith(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildHistoryStatusBadge(context, order),
                  ],
                ),
                const SizedBox(height: 12),

                // Product description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.kPrimaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.productDescription,
                          style: AppTextStyles.bold14,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

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
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 1,
                      ),
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
                          '${AppLocalizations.of(context)!.delivered}: ${_formatDate(order.deliveredAt!)}',
                          style: AppTextStyles.medium18.copyWith(
                            fontSize: 13,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Route summary
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.route, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${order.pickupArea.name} → ${order.deliveryArea.name}',
                        style: AppTextStyles.regular14.copyWith(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryStatusBadge(BuildContext context, order) {
    final l10n = AppLocalizations.of(context)!;

    Color bgColor;
    Color textColor;
    String displayText;
    IconData icon;

    if (order.isCancelled) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      displayText = l10n.cancelled;
      icon = Icons.cancel;
    } else if (order.isDelivered) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      displayText = l10n.delivered;
      icon = Icons.check_circle;
    } else {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
      displayText = order.status;
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

  Widget _buildEmptyState(BuildContext context, {bool isError = false}) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: () => _loadHistory(),
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
                      isError ? Icons.error_outline : Icons.history,
                      size: 80,
                      color: AppColors.kPrimaryColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isError ? l10n.error : l10n.noData,
                    style: AppTextStyles.bold18.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      isError ? l10n.retry : l10n.noAvailableOrders,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => _loadHistory(),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
