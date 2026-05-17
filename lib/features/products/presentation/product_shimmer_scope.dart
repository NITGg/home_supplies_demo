import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProductShimmerScope
//
// Owns exactly one AnimationController that pulses between 0.3 → 0.85 opacity.
// Every ProductSectionSkeleton and _CategoriesSkeletonRow reads it via
// ProductShimmerScope.of(context) instead of creating their own controller.
//
// Usage
// ─────
// 1. Wrap the subtree that contains skeleton widgets:
//
//      ProductShimmerScope(
//        child: Column(children: [
//          OfferedSection(...),
//          BestSellingSection(...),
//          ...
//        ]),
//      )
//
// 2. Inside a skeleton widget, consume the animation:
//
//      final anim = ProductShimmerScope.of(context);
//      AnimatedBuilder(
//        animation: anim,
//        builder: (_, __) => Opacity(opacity: anim.value, child: placeholder),
//      )
//
// If used outside a scope (e.g. in a standalone preview) the fallback path
// returns a constant 0.6-opacity animation so the widget still renders safely.
// ─────────────────────────────────────────────────────────────────────────────

class ProductShimmerScope extends StatefulWidget {
  final Widget child;

  const ProductShimmerScope({super.key, required this.child});

  /// Returns the shared shimmer [Animation<double>] from the nearest
  /// [ProductShimmerScope] ancestor.
  ///
  /// Falls back to a constant 0.6 value when called outside a scope so
  /// skeleton widgets remain safe to use standalone.
  static Animation<double> of(BuildContext context) {
    final scope =
    context.dependOnInheritedWidgetOfExactType<_ShimmerScopeData>();
    return scope?.animation ?? _ConstantAnimation(0.6);
  }

  @override
  State<ProductShimmerScope> createState() => _ProductShimmerScopeState();
}

class _ProductShimmerScopeState extends State<ProductShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScopeData(
      animation: _anim,
      child: widget.child,
    );
  }
}

// ── InheritedWidget carrier ───────────────────────────────────────────────────

class _ShimmerScopeData extends InheritedWidget {
  final Animation<double> animation;

  const _ShimmerScopeData({
    required this.animation,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ShimmerScopeData old) => old.animation != animation;
}

// ── Constant-value fallback animation ────────────────────────────────────────

/// A minimal [Animation<double>] that always returns [value].
/// Used when [ProductShimmerScope.of] is called outside a scope so callers
/// don't have to null-check.
class _ConstantAnimation extends Animation<double> {
  @override
  final double value;

  const _ConstantAnimation(this.value);

  // No listeners needed — this animation never changes.
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.forward;
}