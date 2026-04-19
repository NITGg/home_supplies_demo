import 'package:flutter/material.dart';

import '../data/models/product_model.dart';
import 'quantity_selector.dart';

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final void Function(int quantity)? onQuantityChanged;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onQuantityChanged,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _quantity = 0;

  void _increment() {
    if (widget.product.isOutOfStock) return;
    final max = widget.product.maxAmountForOneOrder;
    if (max != null && _quantity >= max) return;
    setState(() => _quantity++);
    widget.onQuantityChanged?.call(_quantity);
  }

  void _decrement() {
    if (_quantity <= 0) return;
    setState(() => _quantity--);
    widget.onQuantityChanged?.call(_quantity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final primaryColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image section ───────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  _ProductImage(imageUrl: product.primaryImage),

                  // Gradient overlay at bottom for readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.18),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Best seller badge
                  if (product.isBestSeller)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(
                        label: 'الأكثر مبيعاً',
                        color: Colors.amber.shade700,
                        icon: Icons.star_rounded,
                      ),
                    ),

                  // Offer badge
                  if (product.hasOffer)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(
                        label: 'عرض',
                        color: theme.colorScheme.error,
                        icon: Icons.local_offer_rounded,
                      ),
                    ),

                  // Out of stock overlay
                  if (product.isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'نفد المخزون',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Add button / quantity selector (bottom-right) ─────────
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _quantity == 0
                        ? _AddButton(
                      onTap: product.isOutOfStock ? null : _increment,
                      color: primaryColor,
                    )
                        : _QuantityPill(
                      quantity: _quantity,
                      onIncrement: _increment,
                      onDecrement: _decrement,
                      color: primaryColor,
                      max: product.maxAmountForOneOrder,
                    ),
                  ),
                ],
              ),
            ),

            // ── Info section ────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _PriceRow(product: product, primaryColor: primaryColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add button (circle with + icon) ──────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color color;

  const _AddButton({this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: disabled ? Colors.grey.shade300 : color,
          boxShadow: disabled
              ? []
              : [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.add_rounded,
          color: disabled ? Colors.grey.shade500 : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ── Inline quantity pill (shown after first add) ──────────────────────────────

class _QuantityPill extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final Color color;
  final int? max;

  const _QuantityPill({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.color,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    final atMax = max != null && quantity >= max!;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(
                Icons.remove_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          // Increment
          GestureDetector(
            onTap: atMax ? null : onIncrement,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Icon(
                Icons.add_rounded,
                color: atMax ? Colors.white38 : Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: Colors.grey.shade400,
          size: 40,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 9),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final ProductModel product;
  final Color primaryColor;

  const _PriceRow({required this.product, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    if (product.hasOffer) {
      return Row(
        children: [
          Text(
            '${product.offer} ج.م',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${product.price} ج.م',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return Text(
      '${product.effectivePrice.toStringAsFixed(0)} ج.م',
      style: TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}