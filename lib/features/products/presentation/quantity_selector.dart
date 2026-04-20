import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// A compact increment / decrement selector.
///
/// When [quantity] is 0 it renders a simple "أضف" pill.
/// Once [quantity] > 0 it switches to a full +/− control with an animated
/// counter that slides upward on increment and downward on decrement.
class QuantitySelector extends StatefulWidget {
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
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  int _prevQuantity = 0;

  @override
  void didUpdateWidget(QuantitySelector old) {
    super.didUpdateWidget(old);
    _prevQuantity = old.quantity;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // ── Zero state: simple add pill ──────────────────────────────────────────
    if (widget.quantity == 0) {
      return SizedBox(
        height: widget.size,
        child: ElevatedButton.icon(
          onPressed: widget.onIncrement,
          icon: Icon(Icons.add, size: widget.compact ? 14 : 16),
          label: widget.compact
              ? const SizedBox.shrink()
              : Text(l10n.add, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: 0,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.size / 2),
            ),
          ),
        ),
      );
    }

    // ── Non-zero state: +/− pill ─────────────────────────────────────────────
    final canDecrement = widget.quantity > widget.minQuantity;
    final canIncrement =
        widget.maxQuantity == null || widget.quantity < widget.maxQuantity!;

    // Slide direction: up when incrementing, down when decrementing.
    final slideUp = widget.quantity > _prevQuantity;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.size,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(widget.size / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleButton(
            icon: Icons.remove,
            onTap: canDecrement ? widget.onDecrement : null,
            size: widget.size,
            color: cs.onPrimary,
          ),

          // Animated counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: Offset(0, slideUp ? 0.6 : -0.6),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: Text(
                '${widget.quantity}',
                key: ValueKey(widget.quantity),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.compact ? 12 : 14,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ),

          _CircleButton(
            icon: Icons.add,
            onTap: canIncrement ? widget.onIncrement : null,
            size: widget.size,
            color: cs.onPrimary,
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
          color: onTap != null ? color : color.withOpacity(0.35),
        ),
      ),
    );
  }
}