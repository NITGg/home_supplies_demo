import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/cancel_order_sheet.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/proposal_sheet.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/utils/socket_service.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/order_model.dart';
import '../manager/order_cubit.dart';
import '../manager/order_states.dart';
import 'qr_scanner_screen.dart';
import 'widgets/empty_state.dart';
import 'widgets/order_card.dart';
import 'widgets/order_toggle_button.dart';

enum ViewMode { active, history }

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final ScrollController _scrollController = ScrollController();
  ViewMode _viewMode = ViewMode.active;
  String _currentFilter = 'all';

  StreamSubscription? _newOfferSubscription;
  StreamSubscription? _orderCancelledSubscription;

  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().loadActiveOrders();
    _scrollController.addListener(_onScroll);
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cleanupSocketListeners();
    super.dispose();
  }

  // ================= SOCKET SETUP =================

  void _setupSocketListeners() {
    final socketService = SocketService();

    _newOfferSubscription = socketService.onNewOffer.listen((data) {
      if (mounted) _handleNewOffer(data);
    });

    _orderCancelledSubscription = socketService.onOrderCancelled.listen((data) {
      if (mounted) {
        final reason = data['reason'] as String? ?? 'other';
        _handleOrderCancelled(data, reason);
      }
    });
  }

  void _cleanupSocketListeners() {
    _newOfferSubscription?.cancel();
    _orderCancelledSubscription?.cancel();
  }

  // ================= SOCKET EVENT HANDLERS =================

  void _handleNewOffer(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n?.newProposalReceived ?? 'New Proposal Received!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    l10n?.tapToView ?? 'Tap to view details',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n?.view ?? 'View',
          textColor: Colors.white,
          onPressed: () {
            final orderId = data['orderId'] as int?;
            if (orderId != null) _findAndShowProposals(orderId);
          },
        ),
      ),
    );

    if (_viewMode == ViewMode.active) {
      context.read<OrderCubit>().loadActiveOrders(loadMore: false);
    }
  }

  void _handleOrderCancelled(Map<String, dynamic> data, String reason) {
    final l10n = AppLocalizations.of(context);
    final orderId = data['orderId'] as int?;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason == 'unavailable'
                    ? l10n!.orderCancelledUnavailable
                    : l10n!.orderCancelled,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
      ),
    );

    if (orderId != null) SocketService().leaveOrder(orderId);

    if (_viewMode == ViewMode.active) {
      context.read<OrderCubit>().loadActiveOrders(loadMore: false);
    }
  }

  // ================= JOIN ORDER ROOMS =================

  void _joinOrderRooms(List<Order> orders) {
    final socketService = SocketService();
    if (!socketService.isConnected) return;

    final activeOrderIds = orders
        .where((order) => order.id != null && !_isOrderCompleted(order))
        .map((order) => order.id!)
        .toList();

    for (final orderId in activeOrderIds) {
      socketService.joinOrder(orderId);
    }

    socketService.leaveInactiveOrders(activeOrderIds);
  }

  bool _isOrderCompleted(Order order) {
    final completedStatuses = ['DELIVERED', 'CANCELLED'];
    return completedStatuses.contains(order.status?.toUpperCase());
  }

  void _findAndShowProposals(int orderId) {
    final cubit = context.read<OrderCubit>();
    final state = cubit.state;

    if (state is OrdersLoaded) {
      final order = state.orders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => state.orders.first,
      );
      _showProposals(order);
    }
  }

  // ================= SCROLL / PAGINATION =================

  void _onScroll() {
    if (_viewMode != ViewMode.history) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final cubit = context.read<OrderCubit>();
      final state = cubit.state;

      if (state is OrdersLoaded &&
          state.viewMode == OrderViewMode.history &&
          cubit.canLoadMoreHistory()) {
        cubit.loadHistoryOrders(loadMore: true, filter: _currentFilter);
      }
    }
  }

  // ================= TAB / FILTER =================

  void _onTabChanged(ViewMode newMode) {
    setState(() {
      _viewMode = newMode;
      _currentFilter = 'all';
    });

    final cubit = context.read<OrderCubit>();
    final state = cubit.state;

    if (newMode == ViewMode.active) {
      if (state is! OrdersLoaded || state.viewMode != OrderViewMode.active) {
        cubit.loadActiveOrders();
      }
    } else {
      if (state is! OrdersLoaded || state.viewMode != OrderViewMode.history) {
        cubit.loadHistoryOrders(filter: 'all');
      }
    }
  }

  // ================= BOTTOM SHEETS / NAVIGATION =================

  void _showProposals(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<OrderCubit>(),
        child: OrderProposalsSheet(order: order),
      ),
    );
  }

  void _showCancelSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<OrderCubit>(),
        child: OrderCancelBottomSheet(isUnavailable: false, orderId: order.id!),
      ),
    );
  }

  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<OrderCubit>(),
          child: const QRScannerScreen(),
        ),
      ),
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: OrderToggleButton(
          active: _viewMode == ViewMode.active,
          onToggle: (isActive) {
            _onTabChanged(isActive ? ViewMode.active : ViewMode.history);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                color: Colors.grey.shade700,
                onPressed: _navigateToQRScanner,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          final cubit = context.read<OrderCubit>();
          return _viewMode == ViewMode.active
              ? cubit.loadActiveOrders(loadMore: false)
              : cubit.loadHistoryOrders(
                  loadMore: false,
                  filter: _currentFilter,
                );
        },
        color: AppColors.kPrimaryColor,
        child: BlocConsumer<OrderCubit, OrderState>(
          listenWhen: (_, current) =>
              current is OrderCancelled ||
              current is OrderCancelError ||
              current is DeliveryConfirmed ||
              current is OrderError ||
              current is OrderSuccess,
          listener: (context, state) {
            if (state is OrderCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.orderCancelled),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is DeliveryConfirmed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.delivered),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is OrderError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          buildWhen: (previous, current) =>
              current is OrderLoading ||
              current is OrdersLoaded ||
              current is OrderError,
          builder: (context, state) {
            if (state is OrderLoading) return _buildShimmerView();
            if (state is OrderError) return _buildErrorView(state);
            if (state is OrdersLoaded) {
              if (_viewMode == ViewMode.active) _joinOrderRooms(state.orders);
              return _buildOrdersList(state);
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  // ================= SHIMMER =================

  Widget _buildShimmerView() {
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        duration: const Duration(milliseconds: 1200),
      ),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => const _OrderCardSkeleton(),
      ),
    );
  }

  // ================= ERROR =================

  Widget _buildErrorView(OrderError state) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
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
                    Icons.error_outline,
                    size: 80,
                    color: AppColors.kPrimaryColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(state.message),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    final cubit = context.read<OrderCubit>();
                    _viewMode == ViewMode.active
                        ? cubit.loadActiveOrders()
                        : cubit.loadHistoryOrders(filter: _currentFilter);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.retry),
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
    );
  }

  // ================= FILTER CHIPS =================

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
                color: Colors.grey.shade700,
                fontSize: 14,
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
        if (selected && _currentFilter != value) {
          setState(() => _currentFilter = value);
          context.read<OrderCubit>().loadHistoryOrders(filter: value);
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
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

  // ================= ORDERS LIST =================

  bool _shouldShowPaginationSpinner(OrdersLoaded state) {
    if (_viewMode != ViewMode.history) return false;
    if (!state.hasMore) return false;
    if (!context.read<OrderCubit>().canLoadMoreHistory()) return false;
    return true;
  }

  Widget _buildOrdersList(OrdersLoaded state) {
    final isCorrectMode =
        (_viewMode == ViewMode.active &&
            state.viewMode == OrderViewMode.active) ||
        (_viewMode == ViewMode.history &&
            state.viewMode == OrderViewMode.history);

    if (!isCorrectMode) return _buildShimmerView();

    final displayOrders = state.orders;

    if (displayOrders.isEmpty) {
      return Column(
        children: [
          if (_viewMode == ViewMode.history) _buildFilterChips(context),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: OrderEmptyState(viewMode: _viewMode),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (_viewMode == ViewMode.history) _buildFilterChips(context),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount:
                displayOrders.length +
                (_shouldShowPaginationSpinner(state) ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == displayOrders.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.kPrimaryColor,
                    ),
                  ),
                );
              }
              final order = displayOrders[index];
              return OrderCard(
                order: order,
                onViewProposals: () => _showProposals(order),
                onCancel: () => _showCancelSheet(order),
              );
            },
          ),
        ),
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Skeleton that mirrors the real OrderCard's visual structure
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: order id chip + status badge ─────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Order number placeholder
                Container(
                  width: 100,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Status badge placeholder
                Container(
                  width: 72,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Product / description line ────────────────────────────────
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: MediaQuery.of(context).size.width * 0.55,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // ── Meta row: date + price ────────────────────────────────────
            Row(
              children: [
                // Date chip
                Container(
                  width: 90,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                // Price
                Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Action buttons row ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
