import 'package:flutter/material.dart';

import '../../products/presentation/quantity_selector.dart';
import '../data/models/cart_item_model.dart';

class CartItemTile extends StatelessWidget {
  final CartItemModel item;
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

    // Responsive horizontal margin – tighter on narrow screens.
    final hMargin = MediaQuery.of(context).size.width < 360 ? 10.0 : 16.0;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: _SwipeDeleteBackground(theme: theme, hMargin: hMargin),
      confirmDismiss: (_) async {
        onRemove();
        return false; // cubit handles the actual removal
      },
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product image ────────────────────────────────────────────
              _ProductThumb(imageUrl: product.primaryImage),
              const SizedBox(width: 12),

              // ── Info ──────────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      product.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Unit price
                    Text(
                      '${item.unitPrice.toStringAsFixed(0)} ج.م / وحدة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Bottom row: qty selector + line total ──────────────
                    Row(
                      children: [
                        // Quantity selector – replaced by spinner while busy.
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
                            minQuantity: 0, // 0 lets the cubit's decrementItem fire at qty=1 and remove the item
                            maxQuantity: product.maxAmountForOneOrder,
                            size: 32,
                            compact: true,
                          ),
                        ),

                        const Spacer(),

                        // Line total with animated number
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOut,
                                  )),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            '${item.lineTotal.toStringAsFixed(0)} ج.م',
                            key: ValueKey(item.lineTotal),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        child: Icon(
          Icons.inventory_2_outlined,
          color: Colors.grey.shade400,
          size: 28,
        ),
      ),
    );
  }
}

// ── Swipe-to-delete background ────────────────────────────────────────────────

class _SwipeDeleteBackground extends StatelessWidget {
  final ThemeData theme;
  final double hMargin;

  const _SwipeDeleteBackground({
    required this.theme,
    required this.hMargin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: hMargin, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}