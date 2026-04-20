import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/circel_back_cutton.dart';
import '../../../l10n/app_localizations.dart';
import '../manager/cart_cubit.dart';
import '../manager/cart_state.dart';
import 'cart_item_tile.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ── BUG FIX: Do NOT create a private CartCubit here. ─────────────────────
  // CartScreen must read the global CartCubit that is provided by an ancestor
  // BlocProvider so all widgets share the exact same state stream.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CartCubit>().fetchCart();
    });
  }

  CartCubit get _cubit => context.read<CartCubit>();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartCubit, CartState>(
      listenWhen: (_, curr) => curr is CartError,
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
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (state) {
              CartInitial() ||
              CartLoading() =>
              const _LoadingView(key: ValueKey('loading')),
              CartError(:final message) => _ErrorView(
                key: const ValueKey('error'),
                message: message,
                onRetry: _cubit.fetchCart,
              ),
              CartLoaded(:final data) when data.cartItems.isEmpty =>
              const _EmptyView(key: ValueKey('empty')),
              CartLoaded() => _buildLoaded(context, state as CartLoaded),
            },
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, CartState state) {
    final l10n = AppLocalizations.of(context)!;
    final count = state is CartLoaded ? state.data.summary.totalItems : 0;

    return AppBar(
      leading: CircleBackButton(),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.cart),
          if (count > 0) ...[
            const SizedBox(width: 8),
            _CountBadge(count: count),
          ],
        ],
      ),
      actions: [
        if (state is CartLoaded && state.data.cartItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: Icon(Icons.delete_sweep_outlined , color: Colors.grey.shade700,),
                tooltip: l10n.clearCart,
                onPressed: () => _confirmClear(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context, CartLoaded state) {
    final items = state.data.cartItems;
    final summary = state.data.summary;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 360 ? 14.0 : 20.0;

    return Column(
      key: ValueKey('loaded_${items.length}'),
      children: [
        // ── Items list ────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return CartItemTile(
                key: ValueKey(item.id),
                item: item,
                isBusy: state.isItemBusy(item.spId),
                onIncrement: () => _handleIncrement(context, item.spId),
                onDecrement: () => _handleDecrement(context, item.spId),
                onRemove: () => _cubit.removeItem(item.spId),
              );
            },
          ),
        ),

        // ── Summary bar ───────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16 + bottomPadding),
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
              _SummaryRow(
                label: l10n.numberOfItems,
                value: '${summary.itemCount}',
              ),
              const SizedBox(height: 4),
              _SummaryRow(
                label: l10n.totalQuantity,
                value: '${summary.totalItems}',
              ),
              const Divider(height: 20),
              _SummaryRow(
                label: l10n.sum,
                value: '${summary.totalPrice.toStringAsFixed(0)} ${l10n.egp}',
                isTotal: true,
              ),
              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.navigatingToCheckout),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  l10n.proceedToCheckout,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
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

  // ── Action handlers ──────────────────────────────────────────────────────

  void _handleIncrement(BuildContext context, int spId) async {
    try {
      await _cubit.incrementItem(spId);
    } catch (_) {
      if (context.mounted) _showUpdateError(context);
    }
  }

  void _handleDecrement(BuildContext context, int spId) async {
    try {
      await _cubit.decrementItem(spId);
    } catch (_) {
      if (context.mounted) _showUpdateError(context);
    }
  }

  void _showUpdateError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.updateQuantityFailed),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.clearCart),
        content: Text(l10n.clearCartConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.emptyCart),
          ),
        ],
      ),
    );

    if (confirmed == true) await _cubit.clearCart();
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
              ? theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)
              : theme.textTheme.bodyMedium
              ?.copyWith(color: Colors.grey.shade600),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            value,
            key: ValueKey(value),
            style: isTotal
                ? theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            )
                : theme.textTheme.bodyMedium,
          ),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(count),
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
      ),
    );
  }
}

// ── Loading, empty, error states ──────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
              l10n.cartIsEmpty,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.startAddingProducts,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade400),
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
  const _ErrorView(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}