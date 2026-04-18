import 'package:flutter/material.dart';

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final int minQuantity;
  final int? maxQuantity;
  final double size;
  final bool compact;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.minQuantity = 0,
    this.maxQuantity,
    this.size = 28,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (quantity == 0) {
      // Show simple add button when nothing in cart
      return SizedBox(
        height: size,
        child: ElevatedButton.icon(
          onPressed: onIncrement,
          icon: Icon(Icons.add, size: compact ? 14 : 16),
          label: compact
              ? const SizedBox.shrink()
              : const Text('أضف', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: 0,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(size / 2),
            ),
          ),
        ),
      );
    }

    return Container(
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleButton(
            icon: Icons.remove,
            onTap: quantity > minQuantity ? onDecrement : null,
            size: size,
            color: colorScheme.primary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$quantity',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: compact ? 12 : 14,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          _CircleButton(
            icon: Icons.add,
            onTap: (maxQuantity == null || quantity < maxQuantity!)
                ? onIncrement
                : null,
            size: size,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: size * 0.5,
          color: onTap != null ? color : color.withOpacity(0.4),
        ),
      ),
    );
  }
}