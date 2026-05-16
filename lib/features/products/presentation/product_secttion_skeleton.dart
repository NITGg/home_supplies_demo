import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared skeleton widgets for horizontal product sections
// ─────────────────────────────────────────────────────────────────────────────

/// Animated shimmer row — used by every product section while loading.
class ProductSectionSkeleton extends StatefulWidget {
  const ProductSectionSkeleton({super.key});

  @override
  State<ProductSectionSkeleton> createState() => _ProductSectionSkeletonState();
}

class _ProductSectionSkeletonState extends State<ProductSectionSkeleton>
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Fake section label ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Opacity(
              opacity: _anim.value,
              child: Container(
                width: 110,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),

        // ── Fake horizontal card row ───────────────────────────────────────
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, __) => AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Opacity(
                opacity: _anim.value,
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
      ],
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