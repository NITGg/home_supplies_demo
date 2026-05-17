import 'package:flutter/material.dart';
import 'package:tawreedat_go/features/products/presentation/product_shimmer_scope.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared skeleton widgets for horizontal product sections
// ─────────────────────────────────────────────────────────────────────────────

/// Animated shimmer row — used by every product section while loading.
///
/// Reads the pulse animation from the nearest [ProductShimmerScope] so that
/// all sections on-screen pulse in sync with a single [AnimationController].
/// Falls back gracefully (constant opacity) when used outside a scope.
class ProductSectionSkeleton extends StatelessWidget {
  const ProductSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final anim = ProductShimmerScope.of(context);

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Opacity(
          opacity: anim.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Fake section label ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Container(
                  width: 110,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

              // ── Fake horizontal card row ────────────────────────────────
              SizedBox(
                height: 300,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (_, __) => Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Small inline spinner — shown at the end of a list while paginating.
class ProductSectionLoadingCard extends StatelessWidget {
  const ProductSectionLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 60,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}