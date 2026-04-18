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

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(imageUrl: product.primaryImage),
                  if (product.isBestSeller)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(
                        label: 'الأكثر مبيعاً',
                        color: Colors.amber.shade700,
                      ),
                    ),
                  if (product.hasOffer)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _Badge(
                        label: 'عرض',
                        color: theme.colorScheme.error,
                      ),
                    ),
                  if (product.isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black38,
                        alignment: Alignment.center,
                        child: const Text(
                          'نفد المخزون',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Info ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _PriceRow(product: product),
                  const SizedBox(height: 6),
                  QuantitySelector(
                    quantity: _quantity,
                    onIncrement: _increment,
                    onDecrement: _decrement,
                    maxQuantity: product.isOutOfStock
                        ? 0
                        : product.maxAmountForOneOrder,
                    compact: true,
                    size: 26,
                  ),
                ],
              ),
            ),
          ],
        ),
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
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 40),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final ProductModel product;

  const _PriceRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (product.hasOffer) {
      return Row(
        children: [
          Text(
            '${product.offer} ج.م',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${product.price} ج.م',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return Text(
      '${product.price} ج.م',
      style: TextStyle(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}