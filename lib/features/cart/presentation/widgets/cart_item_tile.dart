import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatDate.dart';
import '../../../../core/widgets/highlighter_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../products/presentation/quantity_selector.dart';
import '../../data/models/cart_item_model.dart';

String _fmt(double v) => v.toStringAsFixed(2);

class CartItemTile extends StatelessWidget {
  final CartItemModel item;

  /// True only during a blocking server op (first-add).
  /// Increment / decrement are optimistic and never set this.
  final bool isBusy;

  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.isBusy,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = item.product;
    final l10n = AppLocalizations.of(context)!;
    final hMargin = MediaQuery.of(context).size.width < 360 ? 10.0 : 16.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: hMargin, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/products/${product.id}', extra: product),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductThumb(imageUrl: product.primaryImage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: isBusy
                                  ? _BusySpinner(
                                key: const ValueKey('spinner'),
                                color: theme.colorScheme.primary,
                              )
                                  : QuantitySelector(
                                key: const ValueKey('selector'),
                                quantity: item.quantity,
                                onIncrement: onIncrement,
                                onDecrement: onDecrement,
                                minQuantity: 0,
                                maxQuantity:
                                product.maxAmountForOneOrder,
                                size: 32,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        _PriceBlock(item: item, l10n: l10n, theme: theme),
                        const SizedBox(height: 9),
                        _LineTotalBlock(item: item, theme: theme, l10n: l10n),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (item.readyInFrom > 0 || item.readyInTo > 0)
              _ReadyTimeFooter(
                from: item.readyInFrom,
                to: item.readyInTo,
                l10n: l10n,
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Ready-time footer ─────────────────────────────────────────────────────────

class _ReadyTimeFooter extends StatelessWidget {
  final int from;
  final int to;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _ReadyTimeFooter({
    required this.from,
    required this.to,
    required this.l10n,
    required this.theme,
  });

  String get _label {
    final fromStr = formatDuration(from, l10n);
    if (to == 0 || from == to) return fromStr;
    return '$fromStr – ${formatDuration(to, l10n)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withOpacity(0.5),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                l10n.readyIn,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500),
              ),
              const SizedBox(width: 4),
              Text(
                _label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Price block ───────────────────────────────────────────────────────────────

class _PriceBlock extends StatelessWidget {
  final CartItemModel item;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PriceBlock(
      {required this.item, required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (item.hasDiscount) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HighlighterWidget(
            style: HighlighterStyle.underline,
            child: Text(
              '${_fmt(item.unitPrice)} ${l10n.egp}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_fmt(item.originalPrice)} ${l10n.egp}',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            l10n.perUnit,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      );
    }

    return Text(
      '${_fmt(item.unitPrice)} ${l10n.egp} ${l10n.perUnit}',
      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
    );
  }
}

// ── Line total block ──────────────────────────────────────────────────────────

class _LineTotalBlock extends StatelessWidget {
  final CartItemModel item;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _LineTotalBlock(
      {required this.item, required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: Text(
            '${_fmt(item.lineTotal)} ${l10n.egp}',
            key: ValueKey(item.lineTotal),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (item.hasDiscount && item.lineSaving > 0) ...[
          const SizedBox(height: 4),
          HighlighterWidget(
            child: Text(
              '${l10n.save} ${_fmt(item.lineSaving)} ${l10n.egp}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Busy spinner ──────────────────────────────────────────────────────────────

class _BusySpinner extends StatelessWidget {
  final Color color;

  const _BusySpinner({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 32,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
      ),
    );
  }
}

// ── Product thumbnail ─────────────────────────────────────────────────────────

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;

  const _ProductThumb({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 76,
        height: 76,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.inventory_2_outlined,
            color: Colors.grey.shade400, size: 28),
      ),
    );
  }
}