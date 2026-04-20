import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/image_with_fallback.dart';
import '../../cart/manager/cart_cubit.dart';
import '../../cart/manager/cart_state.dart';
import '../data/models/product_model.dart';

// ── Selector DTO ──────────────────────────────────────────────────────────────
// A tiny value object so [BlocSelector] only triggers rebuilds when this
// product's specific cart data changes, not on every cart mutation.

class _CardCartState {
  final int quantity;
  final bool isBusy;

  const _CardCartState({required this.quantity, required this.isBusy});

  factory _CardCartState.from(CartState state, int? spId) {
    if (state is! CartLoaded || spId == null) {
      return const _CardCartState(quantity: 0, isBusy: false);
    }
    final item =
        state.data.cartItems.where((i) => i.spId == spId).firstOrNull;
    return _CardCartState(
      quantity: item?.quantity ?? 0,
      isBusy: state.isItemBusy(spId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _CardCartState &&
          other.quantity == quantity &&
          other.isBusy == isBusy;

  @override
  int get hashCode => Object.hash(quantity, isBusy);
}

// ── ProductCard ───────────────────────────────────────────────────────────────

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  // Kept for backward compatibility; callers can still observe quantity changes
  // via this callback, but cart state is now the source of truth.
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

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  /// Drives the bounce animation on the add/increment button.
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Spring-like: grow → overshoot → settle.
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.30)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.30, end: 0.88)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 45,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Cart operations ──────────────────────────────────────────────────────

  void _triggerBounce() => _bounceCtrl.forward(from: 0);

  Future<void> _handleAdd(BuildContext ctx) async {
    if (widget.product.isOutOfStock) return;
    HapticFeedback.lightImpact();
    _triggerBounce();
    try {
      await ctx.read<CartCubit>().addItem(
        spId: widget.product.spId ?? widget.product.id,
        quantity: 1,
      );
      widget.onQuantityChanged?.call(1);
    } catch (_) {
      if (ctx.mounted) _showError(ctx);
    }
  }

  Future<void> _handleIncrement(BuildContext ctx, int currentQty) async {
    HapticFeedback.selectionClick();
    _triggerBounce();
    try {
      await ctx
          .read<CartCubit>()
          .incrementItem(widget.product.spId ?? widget.product.id);
      widget.onQuantityChanged?.call(currentQty + 1);
    } catch (_) {
      if (ctx.mounted) _showError(ctx);
    }
  }

  Future<void> _handleDecrement(BuildContext ctx, int currentQty) async {
    HapticFeedback.selectionClick();
    try {
      await ctx
          .read<CartCubit>()
          .decrementItem(widget.product.spId ?? widget.product.id);
      widget.onQuantityChanged?.call(currentQty - 1);
    } catch (_) {
      if (ctx.mounted) _showError(ctx);
    }
  }

  void _showError(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('تعذّر تحديث السلة'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(ctx).colorScheme.error,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final primaryColor = theme.colorScheme.primary;

    return BlocSelector<CartCubit, CartState, _CardCartState>(
      selector: (state) => _CardCartState.from(state, product.spId),
      builder: (ctx, cartState) {
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
                // ── Image + cart control ──────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProductImage(imageUrl: product.primaryImage),

                      // Bottom gradient for badge readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.22),
                              ],
                            ),
                          ),
                        ),
                      ),

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

                      // Out-of-stock overlay
                      if (product.isOutOfStock)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withOpacity(0.50),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
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
                        ),

                      // ── Cart widget (add button ↔ quantity pill) ─────────
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _CartControl(
                          cartState: cartState,
                          product: product,
                          bounceScale: _bounceScale,
                          primaryColor: primaryColor,
                          onAdd: () => _handleAdd(ctx),
                          onIncrement: () =>
                              _handleIncrement(ctx, cartState.quantity),
                          onDecrement: () =>
                              _handleDecrement(ctx, cartState.quantity),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info ──────────────────────────────────────────────────
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
                        _PriceRow(
                          product: product,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Cart control (add button ↔ quantity pill) ─────────────────────────────────

class _CartControl extends StatelessWidget {
  final _CardCartState cartState;
  final ProductModel product;
  final Animation<double> bounceScale;
  final Color primaryColor;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartControl({
    required this.cartState,
    required this.product,
    required this.bounceScale,
    required this.primaryColor,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which child to show; AnimatedSwitcher keys drive the transition.
    final Widget child;
    if (cartState.isBusy) {
      child = _BusyIndicator(key: const ValueKey('busy'), color: primaryColor);
    } else if (cartState.quantity == 0) {
      child = ScaleTransition(
        key: const ValueKey('add'),
        scale: bounceScale,
        child: _AddButton(
          onTap: product.isOutOfStock ? null : onAdd,
          color: primaryColor,
        ),
      );
    } else {
      child = _QuantityPill(
        key: const ValueKey('qty'),
        quantity: cartState.quantity,
        max: product.maxAmountForOneOrder,
        primaryColor: primaryColor,
        bounceScale: bounceScale,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.elasticOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: child,
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
              ? const []
              : [
            BoxShadow(
              color: color.withOpacity(0.38),
              blurRadius: 10,
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

// ── Quantity pill ─────────────────────────────────────────────────────────────

class _QuantityPill extends StatelessWidget {
  final int quantity;
  final int? max;
  final Color primaryColor;
  final Animation<double> bounceScale;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityPill({
    super.key,
    required this.quantity,
    this.max,
    required this.primaryColor,
    required this.bounceScale,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final atMax = max != null && quantity >= max!;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.35),
            blurRadius: 10,
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
            child: SizedBox(
              width: 36,
              height: 36,
              child: const Icon(
                Icons.remove_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // Animated quantity number
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              ),
              child: Text(
                '$quantity',
                key: ValueKey(quantity),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // Increment (bounce-animated)
          GestureDetector(
            onTap: atMax ? null : onIncrement,
            child: ScaleTransition(
              scale: bounceScale,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.add_rounded,
                  color: atMax ? Colors.white38 : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Busy indicator ────────────────────────────────────────────────────────────

class _BusyIndicator extends StatelessWidget {
  final Color color;

  const _BusyIndicator({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
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
      return ImageWithIconFallback(imageUrl: imageUrl,fit: BoxFit.cover,);
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
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