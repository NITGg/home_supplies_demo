import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/formatDate.dart';
import '../../../core/widgets/highlighter_widget.dart';
import '../../../core/widgets/image_with_fallback.dart';
import '../../../core/widgets/login_prompt.dart';               // ← ADD THIS IMPORT
import '../../../l10n/app_localizations.dart';
import '../../cart/data/models/multiple_supplier_exception.dart';
import '../../cart/manager/cart_cubit.dart';
import '../../cart/manager/cart_state.dart';
import '../../cart/presentation/widgets/multiple_supplier_dialog.dart';
import '../../home/layout/manager/guest_cubit.dart';
import '../data/models/product_model.dart';

// ── Price formatting helper ───────────────────────────────────────────────────
String _fmt(double v) => v.toStringAsFixed(2);

// ── Selector DTO ──────────────────────────────────────────────────────────────

class _CardCartState {
  final int quantity;
  final bool isBusy;

  const _CardCartState({required this.quantity, required this.isBusy});

  factory _CardCartState.from(CartState state, int? spId) {
    if (state is! CartLoaded || spId == null) {
      return const _CardCartState(quantity: 0, isBusy: false);
    }
    final item = state.data.cartItems.where((i) => i.spId == spId).firstOrNull;
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
  final void Function(int quantity)? onQuantityChanged;

  /// When false (supplier is currently closed) the add-to-cart controls are
  /// disabled so the user cannot place an order outside opening hours.
  final bool isSupplierOpen;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onQuantityChanged,
    this.isSupplierOpen = true,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.30,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.30,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.88,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 45,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Guest guard ───────────────────────────────────────────────────────────
  //
  // Returns true (and shows the login prompt) when the current session is a
  // guest. All cart handlers call this first and bail out if it returns true.

  bool _isGuest(BuildContext ctx) {
    try {
      return ctx.read<GuestModeCubit>().state;
    } catch (_) {
      // GuestModeCubit not in tree (e.g. standalone usage) — allow cart ops.
      return false;
    }
  }

  void _promptLogin(BuildContext ctx) => showGuestLoginPrompt(ctx);

  // ── Cart operations ───────────────────────────────────────────────────────

  void _triggerBounce() => _bounceCtrl.forward(from: 0);

  Future<void> _handleAdd(BuildContext ctx) async {
    if (_isGuest(ctx)) { _promptLogin(ctx); return; }                 // ← GUARD
    if (widget.product.isOutOfStock || !widget.isSupplierOpen) return;
    HapticFeedback.lightImpact();
    _triggerBounce();
    try {
      await ctx.read<CartCubit>().addItem(
        spId: widget.product.spId ?? widget.product.id,
        quantity: 1,
      );
      widget.onQuantityChanged?.call(1);
    } on MultipleSupplierException catch (e) {
      if (ctx.mounted) {
        await MultipleSupplierDialog.show(ctx, exception: e);
      }
    } catch (e) {
      if (ctx.mounted) _showError(ctx, extractErrorMessage(e));
    }
  }

  Future<void> _handleIncrement(BuildContext ctx, int currentQty) async {
    if (_isGuest(ctx)) { _promptLogin(ctx); return; }                 // ← GUARD
    HapticFeedback.selectionClick();
    _triggerBounce();
    try {
      await ctx.read<CartCubit>().incrementItem(
        widget.product.spId ?? widget.product.id,
      );
      widget.onQuantityChanged?.call(currentQty + 1);
    } catch (e) {
      if (ctx.mounted) _showError(ctx, extractErrorMessage(e));
    }
  }

  Future<void> _handleDecrement(BuildContext ctx, int currentQty) async {
    if (_isGuest(ctx)) { _promptLogin(ctx); return; }                 // ← GUARD
    HapticFeedback.selectionClick();
    try {
      await ctx.read<CartCubit>().decrementItem(
        widget.product.spId ?? widget.product.id,
      );
      widget.onQuantityChanged?.call(currentQty - 1);
    } catch (e) {
      if (ctx.mounted) _showError(ctx, extractErrorMessage(e));
    }
  }

  void _showError(BuildContext ctx, [String? message]) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message ?? AppLocalizations.of(ctx)!.cartUpdateFailed),
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
    final l10n = AppLocalizations.of(context)!;

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
                      if (product.requiresDeliveryWindows)
                        const Positioned(
                          bottom: 8,
                          left: 8,
                          child: _DeliveryWindowBadge(),
                        )
                      else if (product.pickupReadyDurationFrom != null)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: _ReadyTimePill(
                            minutes: product.pickupReadyDurationFrom!,
                            minutesTo: product.pickupReadyDurationTo,
                          ),
                        ),
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
                            label: l10n.bestSeller,
                            color: Colors.amber.shade700,
                            icon: Icons.star_rounded,
                          ),
                        ),

                      if (product.hasOffer)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: product.discountPercent != null
                              ? _Badge(
                            label: l10n.percentOff(
                              product.discountPercent!,
                            ),
                            color: AppColors.kDiscountColor,
                            icon: Icons.card_giftcard,
                          )
                              : _Badge(
                            label: l10n.offer,
                            color: AppColors.kDiscountColor,
                            icon: Icons.card_giftcard,
                          ),
                        ),

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
                                child: Text(
                                  l10n.outOfStock,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _CartControl(
                          cartState: cartState,
                          product: product,
                          bounceScale: _bounceScale,
                          primaryColor: primaryColor,
                          isSupplierOpen: widget.isSupplierOpen,
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
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
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

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (product.totalReviews > 0) ...[
                              _RatingPill(
                                rating: product.rating,
                                reviewCount: product.totalReviews,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: _PriceRow(
                                  product: product,
                                  primaryColor: primaryColor,
                                ),
                              ),
                            ),
                          ],
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

// ── Cart control ──────────────────────────────────────────────────────────────

class _CartControl extends StatelessWidget {
  final _CardCartState cartState;
  final ProductModel product;
  final Animation<double> bounceScale;
  final Color primaryColor;
  final bool isSupplierOpen;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartControl({
    required this.cartState,
    required this.product,
    required this.bounceScale,
    required this.primaryColor,
    this.isSupplierOpen = true,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSupplierOpen && !product.isOutOfStock) {
      return _AddButton(onTap: null, color: primaryColor);
    }

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

// ── Add button ────────────────────────────────────────────────────────────────

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
          GestureDetector(
            onTap: onDecrement,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.remove_rounded, color: Colors.white, size: 18),
            ),
          ),
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

// ── Rating pill ───────────────────────────────────────────────────────────────

class _RatingPill extends StatelessWidget {
  final double rating;
  final int reviewCount;

  const _RatingPill({required this.rating, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    final score = rating % 1 == 0
        ? rating.toInt().toString()
        : rating.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: Colors.amber.shade600),
          const SizedBox(width: 2),
          Text(
            score,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.amber.shade800,
              height: 1,
            ),
          ),
          Text(
            ' ($reviewCount)',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
              height: 1,
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
      return ImageWithIconFallback(imageUrl: imageUrl, fit: BoxFit.cover);
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

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
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
          Icon(icon, color: Colors.black, size: 9),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Price row ─────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final ProductModel product;
  final Color primaryColor;

  const _PriceRow({required this.product, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (product.hasOffer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          HighlighterWidget(
            child: Text(
              '${_fmt(product.offer!)} ${l10n.egp}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${_fmt(product.price)} ${l10n.egp}',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 9,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.grey.shade400,
            ),
          ),
        ],
      );
    }

    return Text(
      '${_fmt(product.effectivePrice)} ${l10n.egp}',
      style: TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}

// ── Delivery window badge ─────────────────────────────────────────────────────

/// Shown on product cards when [ProductModel.requiresDeliveryWindows] is true.
/// A simple pill indicating the product needs scheduled-window delivery so the
/// user knows before tapping that ordering requires a delivery slot.
class _DeliveryWindowBadge extends StatelessWidget {
  const _DeliveryWindowBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.indigo.shade700.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded, size: 10, color: Colors.white),
          SizedBox(width: 3),
          Text(
            l10n.preOrder,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyTimePill extends StatelessWidget {
  final int minutes;
  final int? minutesTo;           // ← ADD

  const _ReadyTimePill({
    required this.minutes,
    this.minutesTo,               // ← ADD
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Build "5 min" OR "5–10 min" depending on whether `to` is set and differs
    final String text;
    if (minutesTo != null && minutesTo != minutes) {
      text = formatDurationRange(minutes, minutesTo!, l10n);  // ← "10–20 min"
    } else {
      text = formatDuration(minutes, l10n);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              overflow: TextOverflow.ellipsis,
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}