import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../manager/cart_cubit.dart';
import '../manager/cart_state.dart';
import 'cart_item_tile.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final CartCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = CartCubit()..fetchCart();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<CartCubit, CartState>(
        listenWhen: (_, current) => current is CartError,
        listener: (context, state) {
          if (state is CartError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: _buildAppBar(context, state),
            body: switch (state) {
              CartInitial() || CartLoading() => const _LoadingView(),
              CartError(:final message) => _ErrorView(
                message: message,
                onRetry: _cubit.fetchCart,
              ),
              CartLoaded(:final data) when data.cartItems.isEmpty =>
                const _EmptyView(),
              CartLoaded() => _buildLoaded(context, state as CartLoaded),
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, CartState state) {
    final count = state is CartLoaded ? state.data.summary.totalItems : 0;

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('السلة'),
          if (count > 0) ...[
            const SizedBox(width: 8),
            _CountBadge(count: count),
          ],
        ],
      ),
      actions: [
        if (state is CartLoaded && state.data.cartItems.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'تفريغ السلة',
            onPressed: () => _confirmClear(context),
          ),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context, CartLoaded state) {
    final items = state.data.cartItems;
    final summary = state.data.summary;
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        // ── Items list ───────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return CartItemTile(
                key: ValueKey(item.id),
                item: item,
                isBusy: state.isItemBusy(item.id),
                onIncrement: () => _handleIncrement(context, item.spId),
                onDecrement: () => _handleDecrement(context, item.spId),
                onRemove: () => _cubit.removeItem(item.spId),
              );
            },
          ),
        ),

        // ── Summary bar ──────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Order summary
              _SummaryRow(label: 'عدد الأصناف', value: '${summary.itemCount}'),
              const SizedBox(height: 4),
              _SummaryRow(
                label: 'إجمالي الكميات',
                value: '${summary.totalItems}',
              ),
              const Divider(height: 20),
              _SummaryRow(
                label: 'الإجمالي',
                value: '${summary.totalPrice.toStringAsFixed(0)} ج.م',
                isTotal: true,
              ),
              const SizedBox(height: 16),

              // Checkout button
              FilledButton.icon(
                onPressed: () {
                  // TODO: navigate to checkout
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الانتقال إلى إتمام الطلب...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'إتمام الطلب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleIncrement(BuildContext context, int itemId) async {
    try {
      await _cubit.incrementItem(itemId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذّر تحديث الكمية'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleDecrement(BuildContext context, int itemId) async {
    try {
      await _cubit.decrementItem(itemId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذّر تحديث الكمية'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تفريغ السلة'),
        content: const Text('هل أنت متأكد من حذف جميع المنتجات من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تفريغ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cubit.clearCart();
    }
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
        ),
        Text(
          value,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

// ── Count badge ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Loading, empty, error states ──────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'السلة فارغة',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف بعض المنتجات للبدء',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
