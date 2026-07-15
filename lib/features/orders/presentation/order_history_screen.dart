import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/utils/secure_storage_service.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/empty_state.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/order_card.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/orders_shimmers.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/orders_model.dart';
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
  Set<int> _hiddenOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadHiddenIds();
    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadHiddenIds() async {
    final ids = await SecureStorageService().getHiddenOrderIds();
    if (mounted) setState(() => _hiddenOrderIds = ids);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<OrderCubit>().loadMoreHistory();
    }
  }

  Future<void> _loadHistory({String? filter}) async {
    final filterToUse = filter ?? _currentFilter;
    setState(() => _currentFilter = filterToUse);
    await context.read<OrderCubit>().fetchOrderHistory(
      refresh: true,
      filter: filterToUse,
    );
  }

  // ─── Status helpers ───────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.schedule;
      case 'IN_PROGRESS':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'PENDING':
        return l10n.pending;
      case 'IN_PROGRESS':
        return l10n.inProgress;
      case 'DELIVERED':
        return l10n.delivered;
      case 'CANCELLED':
        return l10n.cancelled ?? 'Cancelled';
      default:
        return status;
    }
  }

  // String _formatDate(DateTime date) {
  //   final now = DateTime.now();
  //   final diff = now.difference(date);
  //   if (diff.inDays == 0) {
  //     return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  //   } else if (diff.inDays == 1) {
  //     return 'Yesterday';
  //   } else if (diff.inDays < 7) {
  //     return '${diff.inDays} days ago';
  //   } else {
  //     return '${date.day}/${date.month}/${date.year}';
  //   }
  // }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.kBackgroundColor,
      child: BlocConsumer<OrderCubit, OrderState>(
        buildWhen: (_, current) =>
            current is OrderHistoryLoaded ||
            current is OrderHistoryLoading ||
            current is OrderHistoryInitial ||
            current is OrderHistoryError,
        listener: (context, state) {
          if (state is OrderHistoryError) {
            showErrorBanner(context, state.message);
          }
        },
        builder: (context, state) {
          final visible = state is OrderHistoryLoaded
              ? state.orders
                  .where((o) => !_hiddenOrderIds.contains(o.id))
                  .toList()
              : <OrderModel>[];

          return Column(
            children: [
              _buildFilterChips(context, visible),
              Expanded(
                child: () {
                  if (state is OrderHistoryLoading && !state.isLoadingMore) {
                    return OrderShimmers.orderHistoryListShimmer();
                  }
                  if (state is OrderHistoryInitial) {
                    return OrderShimmers.orderHistoryListShimmer();
                  }
                  if (state is OrderHistoryLoaded) {
                    if (visible.isEmpty) return _buildEmptyState(context);
                    return RefreshIndicator(
                      onRefresh: () => _loadHistory(),
                      color: AppColors.kPrimaryColor,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= visible.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.kPrimaryColor,
                                ),
                              ),
                            );
                          }
                          return _buildDismissibleCard(context, visible[index]);
                        },
                      ),
                    );
                  }
                  if (state is OrderHistoryError) {
                    return _buildEmptyState(context, isError: true);
                  }
                  return const SizedBox.shrink();
                }(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Filter chips ─────────────────────────────────────────────────────────

  Widget _buildFilterChips(BuildContext context, List<OrderModel> visibleOrders) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    value: 'DELIVERED',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: l10n.cancelled,
                    value: 'CANCELLED',
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),
          // Swipe hint + clear all row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Icon(Icons.swipe_left_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  l10n.swipeToHide,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
                const Spacer(),
                if (visibleOrders.isNotEmpty)
                  GestureDetector(
                    onTap: () => _clearAllHistory(context, visibleOrders),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_sweep_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          l10n.clearAll,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
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
        if (selected) _loadHistory(filter: value);
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

  // ─── Dismissible wrapper ──────────────────────────────────────────────────

  Widget _buildDismissibleCard(BuildContext context, OrderModel order) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Dismissible(
      key: ValueKey(order.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
        padding: isRtl
            ? const EdgeInsets.only(left: 24)
            : const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        setState(() => _hiddenOrderIds.add(order.id));
        await SecureStorageService().addHiddenOrderId(order.id);
        if (mounted) {
          showSuccessBanner(
            context,
            l10n.orderHidden,
            actionLabel: l10n.undo,
            onAction: () async {
              await SecureStorageService().removeHiddenOrderId(order.id);
              if (mounted) setState(() => _hiddenOrderIds.remove(order.id));
            },
          );
        }
        return false;
      },
      child: _buildHistoryOrderCard(context, order),
    );
  }

  void _clearAllHistory(BuildContext context, List<OrderModel> visibleOrders) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.clearAll),
        content: Text(l10n.clearAllOrdersConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              final ids = visibleOrders.map((o) => o.id).toSet();
              setState(() => _hiddenOrderIds.addAll(ids));
              Future.wait(ids.map((id) => SecureStorageService().addHiddenOrderId(id)));
              showSuccessBanner(
                context,
                l10n.allOrdersHidden,
                actionLabel: l10n.undo,
                onAction: () async {
                  await Future.wait(
                    ids.map((id) => SecureStorageService().removeHiddenOrderId(id)),
                  );
                  if (mounted) setState(() => _hiddenOrderIds.removeAll(ids));
                },
              );
            },
            child: Text(l10n.clearAll, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── History card ─────────────────────────────────────────────────────────

  Widget _buildHistoryOrderCard(BuildContext context, OrderModel order) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName == 'ar';
    final statusColor = _statusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: AppColors.kSecondaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/orders/details', extra: order),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, statusColor.withOpacity(0.03)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: order number, date, status badge
              _buildCardHeader(context, order, statusColor),

              // Product image + description
              _buildProductInfo(context, order),

              // Delivery outcome (delivered date or cancellation reason)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildOutcomeInfo(context, order, isArabic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
    BuildContext context,
    OrderModel order,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _statusIcon(order.status),
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber, style: AppTextStyles.bold16),
                Text(
                  formatDate(context, order.createdAt),
                  style: AppTextStyles.regular14.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(order.status), size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(context, order.status),
                  style: AppTextStyles.bold14.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Matches the product image + description block from OrderCardWidget.
  Widget _buildProductInfo(BuildContext context, OrderModel order) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              spacing: 5,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        '${(order.actualPrice == '0' || order.actualPrice == null) ? order.budget : order.actualPrice} ${l10n.egp}',
                        style: AppTextStyles.bold14.copyWith(
                          fontSize: 13,
                          color: AppColors.kSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
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
                        Icons.percent,
                        size: 16,
                        color: AppColors.kSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${l10n.yourDeliveryFee}: ${(order.courierFee)??0} ${l10n.egp}',
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

  /// Cancellation reason or delivered-at timestamp.
  Widget _buildOutcomeInfo(
    BuildContext context,
    OrderModel order,
    bool isArabic,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (order.isCancelled && order.cancelledReason != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reason,
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
      );
    }

    if (order.isDelivered && order.deliveredAt != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              '${l10n.delivered}: ${formatDate(context, order.deliveredAt!)}',
              style: AppTextStyles.medium18.copyWith(
                fontSize: 13,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      );
    }

    // Route summary for other statuses
    return Row(
      children: [
        Icon(Icons.route, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            isArabic
                ? '${order.pickupArea?.nameAr} → ${order.deliveryArea?.nameAr}'
                : '${order.pickupArea?.name} → ${order.deliveryArea?.name}',
            style: AppTextStyles.regular14.copyWith(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, {bool isError = false}) {
    final l10n = AppLocalizations.of(context)!;
    return AppEmptyState(
      icon: isError ? Icons.error_outline : Icons.history,
      title: isError ? l10n.error : l10n.noData,
      subtitle: isError ? '' : l10n.noAvailableOrders,
      onRefresh: _loadHistory,
      useScroll: true,
    );
  }
}
