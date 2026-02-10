import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/cancel_order_dialog.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/proposal_sheet.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/order_model.dart';
import '../manager/order_cubit.dart';
import '../manager/order_states.dart';
import 'qr_scanner_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().loadOrders();
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
      final state = context.read<OrderCubit>().state;
      if (state is OrdersLoaded && state.hasMore) {
        context.read<OrderCubit>().loadOrders(page: state.currentPage + 1);
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

  void _showCancelDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: context.read<OrderCubit>(),
        child: CancelOrderDialog(order: order),
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
        title: Text(
          AppLocalizations.of(context)?.orders ?? 'Orders',
          style: AppTextStyles.bold18,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade300,
              child: IconButton(
                icon: Icon(Icons.qr_code_scanner),
                color: Colors.grey,
                onPressed:_navigateToQRScanner
              ),
            ),
          )
        ],
      ),
      body: BlocConsumer<OrderCubit, OrderState>(
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
              const SnackBar(
                content: Text('Delivery confirmed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is OrderLoading) {
            return const Center(
              child: LoadingScreen(isOne: true, asWidget: true),
            );
          }

          if (state is OrderError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<OrderCubit>().loadOrders(),
                    child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is OrdersLoaded) {
            if (state.orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No orders yet',
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<OrderCubit>().loadOrders(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.orders.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.orders.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final order = state.orders[index];
                  return _OrderCard(
                    order: order,
                    onViewProposals: () => _showProposals(order),
                    onCancel: () => _showCancelDialog(order),
                  );
                },
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onViewProposals;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.onViewProposals,
    required this.onCancel,
  });

  Color _getStatusColor() {
    switch (order.status) {
      case 'PENDING':
        return Colors.orange;
      case 'ACCEPTED':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (order.status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'ACCEPTED':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with order number and status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(), color: _getStatusColor(), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber ?? 'N/A',
                        style: AppTextStyles.bold16,
                      ),
                      if (order.createdAt != null)
                        Text(
                          dateFormat.format(order.createdAt!),
                          style: AppTextStyles.regular14.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status ?? 'N/A',
                    style: AppTextStyles.bold14.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Order Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Description
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shopping_bag,
                        size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.productDescription,
                        style: AppTextStyles.regular14,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Budget
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Budget: ${order.budget} EGP',
                      style: AppTextStyles.bold14.copyWith(
                        color: AppColors.kPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pickup Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.my_location, size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pickup',
                              style: AppTextStyles.bold14
                                  .copyWith(color: Colors.green)),
                          Text(
                            order.pickupAddressDescription,
                            style: AppTextStyles.regular14,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Delivery Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery',
                              style: AppTextStyles.bold14
                                  .copyWith(color: Colors.blue)),
                          Text(
                            order.deliveryAddressDescription,
                            style: AppTextStyles.regular14,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          if (order.isPending) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewProposals,
                      icon: const Icon(Icons.local_offer, size: 18),
                      label: const Text('View Proposals'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}