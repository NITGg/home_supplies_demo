import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../cart/manager/cart_cubit.dart';
import '../data/models/multiple_supplier_exception.dart';

/// Shows a modal bottom sheet when the user tries to add a product from a
/// different supplier than the items already in their cart.
///
/// The user can either:
///   • **Clear cart & add** — wipes the cart, then adds the pending item.
///   • **Keep cart**        — dismisses without making any change.
///
/// Usage:
/// ```dart
/// } on MultipleSupplierException catch (e) {
///   if (context.mounted) {
///     await MultipleSupplierDialog.show(context, exception: e);
///   }
/// }
/// ```
class MultipleSupplierDialog extends StatefulWidget {
  final MultipleSupplierException exception;

  const MultipleSupplierDialog._({required this.exception});

  /// Opens the sheet and waits until it is dismissed.
  static Future<void> show(
      BuildContext context, {
        required MultipleSupplierException exception,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Rounded top corners + drag handle via shape
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MultipleSupplierDialog._(exception: exception),
    );
  }

  @override
  State<MultipleSupplierDialog> createState() => _MultipleSupplierDialogState();
}

class _MultipleSupplierDialogState extends State<MultipleSupplierDialog> {
  bool _isLoading = false;

  Future<void> _handleClearAndAdd(BuildContext ctx) async {
    setState(() => _isLoading = true);
    try {
      await ctx.read<CartCubit>().clearAndAddItem(
        spId: widget.exception.pendingSpId,
        quantity: widget.exception.pendingQuantity,
      );
      if (ctx.mounted) Navigator.of(ctx).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (ctx.mounted) {
        final l10n = AppLocalizations.of(ctx)!;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(l10n.cartUpdateFailed),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Icon ────────────────────────────────────────────────────────
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store_mall_directory_outlined,
              size: 32,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ────────────────────────────────────────────────────────
          Text(
            l10n.differentSupplierTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ── Body ─────────────────────────────────────────────────────────
          Text(
            l10n.differentSupplierBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // ── Clear & add button ────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _handleClearAndAdd(context),
            icon: _isLoading
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            )
                : const Icon(Icons.delete_sweep_outlined),
            label: Text(
              l10n.clearCartAndAdd,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Keep cart button ──────────────────────────────────────────────
          OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              l10n.keepMyCart,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}