import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/cancel_order_sheet.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/proposal_sheet.dart';
import '../../../core/style/app_colors.dart';
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

  // Stream subscriptions
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

    // Subscribe to new offer stream
    _newOfferSubscription = socketService.onNewOffer.listen((data) {
      if (mounted) {
        _handleNewOffer(data);
      }
    });

    // Subscribe to order cancelled stream
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

    // Note: We don't leave order rooms here anymore
    // Rooms are only left when orders are completed/cancelled
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
            if (orderId != null) {
              _findAndShowProposals(orderId);
            }
          },
        ),
      ),
    );

    // Refresh active orders
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
                    ? (l10n?.orderCancelledUnavailable ?? 'Order cancelled - Item unavailable')
                    : (l10n?.orderCancelled ?? 'Order cancelled'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
      ),
    );

    // Leave the order room since it's completed
    if (orderId != null) {
      SocketService().leaveOrder(orderId);
    }

    // Refresh the list
    if (_viewMode == ViewMode.active) {
      context.read<OrderCubit>().loadActiveOrders(loadMore: false);
    }
  }

  // ================= JOIN ORDER ROOMS =================
  void _joinOrderRooms(List<Order> orders) {
    final socketService = SocketService();

    if (!socketService.isConnected) return;

    // Get list of active order IDs that need real-time updates
    final activeOrderIds = orders
        .where((order) => order.id != null && !_isOrderCompleted(order))
        .map((order) => order.id!)
        .toList();

    // Join rooms for active orders
    for (final orderId in activeOrderIds) {
      socketService.joinOrder(orderId);
    }

    // Leave rooms for orders that are no longer in the list
    socketService.leaveInactiveOrders(activeOrderIds);
  }

  // Helper to determine if an order is completed
  bool _isOrderCompleted(Order order) {
    // Adjust these status strings to match your actual order statuses
    final completedStatuses = ['DELIVERED', 'CANCELLED'];
    return completedStatuses.contains(order.status?.toLowerCase());
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

  // ================= EXISTING METHODS =================

  void _onScroll() {
    if (_viewMode != ViewMode.history) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final cubit = context.read<OrderCubit>();
      final state = cubit.state;

      if (state is OrdersLoaded &&
          state.viewMode == OrderViewMode.history &&
          cubit.canLoadMoreHistory()) {
        cubit.loadHistoryOrders(loadMore: true);
      }
    }
  }

  void _onTabChanged(ViewMode newMode) {
    setState(() => _viewMode = newMode);

    final cubit = context.read<OrderCubit>();
    final state = cubit.state;

    if (newMode == ViewMode.active) {
      if (state is! OrdersLoaded || state.viewMode != OrderViewMode.active) {
        cubit.loadActiveOrders();
      }
    } else {
      if (state is! OrdersLoaded || state.viewMode != OrderViewMode.history) {
        cubit.loadHistoryOrders();
      }
    }
  }

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
        child: OrderCancelBottomSheet(
            isUnavailable: false, orderId: order.id!),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              : cubit.loadHistoryOrders(loadMore: false);
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
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is DeliveryConfirmed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)?.delivered ??
                        'Delivery confirmed successfully!',
                  ),
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
            if (state is OrderLoading) {
              return _buildShimmerView();
            }

            if (state is OrderError) {
              return _buildErrorView(state);
            }

            if (state is OrdersLoaded) {
              // Join socket rooms for active orders
              if (_viewMode == ViewMode.active) {
                _joinOrderRooms(state.orders);
              }
              return _buildOrdersList(state);
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  // ── Shimmer loading view ───────────────────────────────────────────────────

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

  // ── Error view ─────────────────────────────────────────────────────────────

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
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final cubit = context.read<OrderCubit>();
                    _viewMode == ViewMode.active
                        ? cubit.loadActiveOrders()
                        : cubit.loadHistoryOrders();
                  },
                  child:
                  Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Orders list ────────────────────────────────────────────────────────────

  Widget _buildOrdersList(OrdersLoaded state) {
    final isCorrectMode =
        (_viewMode == ViewMode.active &&
            state.viewMode == OrderViewMode.active) ||
            (_viewMode == ViewMode.history &&
                state.viewMode == OrderViewMode.history);

    if (!isCorrectMode) {
      return _buildShimmerView();
    }

    if (state.orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: OrderEmptyState(viewMode: _viewMode),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.orders.length +
          (_viewMode == ViewMode.history && state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Pagination spinner at the bottom
        if (index == state.orders.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(
              color: AppColors.kPrimaryColor,
            )),
          );
        }

        final order = state.orders[index];
        return OrderCard(
          order: order,
          onViewProposals: () => _showProposals(order),
          onCancel: () => _showCancelSheet(order),
        );
      },
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