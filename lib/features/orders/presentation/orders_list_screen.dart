import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/cancel_order_dialog.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/empty_state.dart';
import 'package:tawreedat_go/features/orders/presentation/widgets/proposal_sheet.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/order_model.dart';
import '../manager/order_cubit.dart';
import '../manager/order_states.dart';
import 'qr_scanner_screen.dart';

// ─── Toggle mode ─────────────────────────────────────────────────────────────
enum _ViewMode { active, history }

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final ScrollController _scrollController = ScrollController();
  _ViewMode _viewMode = _ViewMode.active;

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

  /// Filter orders based on current view mode.
  List<Order> _filter(List<Order> all) {
    if (_viewMode == _ViewMode.active) {
      // Active = PENDING or ACCEPTED
      return all
          .where((o) => o.status == 'PENDING' || o.status == 'ACCEPTED')
          .toList();
    } else {
      // History = DELIVERED or CANCELLED
      return all
          .where((o) => o.status == 'DELIVERED' || o.status == 'CANCELLED')
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _ToggleButton(
          active: _viewMode == _ViewMode.active,
          onToggle: (isActive) {
            setState(() {
              _viewMode = isActive ? _ViewMode.active : _ViewMode.history;
            });
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
                    child: Text(
                      AppLocalizations.of(context)?.retry ?? 'Retry',
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is OrdersLoaded) {
            final filtered = _filter(state.orders);

            if (filtered.isEmpty) {
              return _EmptyState(viewMode: _viewMode);
            }

            return RefreshIndicator(
              onRefresh: () => context.read<OrderCubit>().loadOrders(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == filtered.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final order = filtered[index];
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

// ─── Toggle Button ────────────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onToggle;

  const _ToggleButton({required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 5,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label: AppLocalizations.of(context)?.orders ?? 'Orders',
            selected: active,
            onTap: () => onToggle(true),
          ),
          _Tab(
            label: AppLocalizations.of(context)?.history ?? 'History',
            selected: !active,
            onTap: () => onToggle(false),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:
          selected ? AppColors.kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
            selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _ViewMode viewMode;

  const _EmptyState({required this.viewMode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = viewMode == _ViewMode.active;

    return AppEmptyState(
      icon: isActive ? Icons.shopping_bag_outlined : Icons.history_outlined,
      title: isActive
          ? l10n.noActiveOrder
          : l10n.noData,
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onViewProposals;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.onViewProposals,
    required this.onCancel,
  });

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _statusColor() {
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

  IconData _statusIcon() {
    switch (order.status) {
      case 'PENDING':
        return Icons.schedule;
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

  String _statusLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (order.status) {
      case 'PENDING':
        return l10n?.pending ?? 'Pending';
      case 'ACCEPTED':
        return 'Accepted';
      case 'DELIVERED':
        return l10n?.delivered ?? 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return order.status ?? '';
    }
  }

  // ── Date helper ───────────────────────────────────────────────────────────

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: AppColors.kPrimaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              statusColor.withOpacity(0.03),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.07),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                    Icon(_statusIcon(), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber ?? 'N/A',
                          style: AppTextStyles.bold16,
                        ),
                        Text(
                          _formatDate(order.createdAt),
                          style: AppTextStyles.regular14.copyWith(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(),
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(context),
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
            ),

            // ── Product info ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description & budget
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.kPrimaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 20,
                          color: AppColors.kPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.productDescription,
                              style: AppTextStyles.bold14.copyWith(
                                fontSize: 15,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            _BudgetChip(budget: order.budget),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Route
                  _RouteSection(order: order),
                ],
              ),
            ),

            // ── Action buttons (PENDING only) ────────────────────────────────
            if (order.isPending) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onViewProposals,
                        icon: const Icon(Icons.local_offer, size: 16),
                        label: const Text('View Proposals'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.kPrimaryColor,
                          side: BorderSide(
                              color: AppColors.kPrimaryColor.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                            color: Colors.red.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Budget chip ──────────────────────────────────────────────────────────────

class _BudgetChip extends StatelessWidget {
  final String budget;
  const _BudgetChip({required this.budget});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.kSecondaryColor.withOpacity(0.12),
            AppColors.kSecondaryColor.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.kSecondaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 14,
            color: AppColors.kSecondaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${l10n?.budget ?? 'Budget'}: $budget ${l10n?.egp ?? 'EGP'}',
            style: AppTextStyles.bold14.copyWith(
              fontSize: 12,
              color: AppColors.kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Route section ────────────────────────────────────────────────────────────

class _RouteSection extends StatelessWidget {
  final Order order;
  const _RouteSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _LocationRow(
            icon: Icons.my_location,
            label: AppLocalizations.of(context)?.pickup ?? 'Pickup',
            address: order.pickupAddressDescription,
            color: Colors.green,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 1.5,
                  height: 16,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.only(left: 11),
                ),
              ],
            ),
          ),
          _LocationRow(
            icon: Icons.location_on,
            label: AppLocalizations.of(context)?.delivery ?? 'Delivery',
            address: order.deliveryAddressDescription,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color color;

  const _LocationRow({
    required this.icon,
    required this.label,
    required this.address,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bold14.copyWith(
                  fontSize: 11,
                  color: color,
                ),
              ),
              Text(
                address,
                style: AppTextStyles.regular14.copyWith(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}