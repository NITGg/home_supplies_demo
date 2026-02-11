import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/cancel_order_sheet.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/sheets/proposal_sheet.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().loadActiveOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Only paginate in history tab
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
              return _buildLoadingView();
            }

            if (state is OrderError) {
              return _buildErrorView(state);
            }

            if (state is OrdersLoaded) {
              return _buildOrdersList(state);
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: const Center(
            child: LoadingScreen(isOne: true, asWidget: true),
          ),
        ),
      ],
    );
  }

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
                  child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList(OrdersLoaded state) {
    final isCorrectMode =
        (_viewMode == ViewMode.active &&
            state.viewMode == OrderViewMode.active) ||
        (_viewMode == ViewMode.history &&
            state.viewMode == OrderViewMode.history);

    if (!isCorrectMode) {
      return _buildLoadingView();
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
      itemCount:
          state.orders.length +
          (_viewMode == ViewMode.history && state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.orders.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
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
