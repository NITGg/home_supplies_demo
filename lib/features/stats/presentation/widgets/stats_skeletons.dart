import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shimmer skeletons for the StatsScreen.
///
/// Each public method returns the skeleton counterpart of a real section:
///  - [BadgeProgressSkeleton]   → mirrors BadgeProgressSection
///  - [EarningsSummarySkeleton] → mirrors EarningsSummarySection
///  - [PerformanceSkeleton]     → mirrors PerformanceSection
///
/// All skeletons share the same [_shimmerEffect] so the animation is
/// visually consistent across the whole screen.

const _kShimmerEffect = ShimmerEffect(
  baseColor: Color(0xFFE8E8E8),
  highlightColor: Color(0xFFF5F5F5),
  duration: Duration(milliseconds: 1200),
);

// ─────────────────────────────────────────────────────────────────────────────
// Badge Progress Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class BadgeProgressSkeleton extends StatelessWidget {
  const BadgeProgressSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: _kShimmerEffect,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Keep the same dark gradient shape so the skeleton has the right
          // dimensions; the shimmer paints over it anyway.
          gradient: const LinearGradient(
            colors: [Color(0xFF2D3436), Color(0xFF636E72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Bone.text(words: 2, fontSize: 18),
                Row(
                  children: [
                    Bone(
                      width: 80,
                      height: 32,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(width: 8),
                    Bone.square(size: 32, borderRadius: BorderRadius.circular(50)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Progress bar ──────────────────────────────────────────
            Bone(
              width: double.infinity,
              height: 12,
              borderRadius: BorderRadius.circular(10),
            ),

            const SizedBox(height: 12),

            // ── Progress text row ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Bone.text(words: 3, fontSize: 14),
                Bone.text(words: 1, fontSize: 14),
              ],
            ),

            const SizedBox(height: 20),

            // ── Badge info row ────────────────────────────────────────
            Row(
              children: [
                Bone.square(size: 94, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone.text(words: 8, fontSize: 13),
                      const SizedBox(height: 6),
                      Bone.text(words: 4, fontSize: 13),
                      const SizedBox(height: 4),
                      Bone.text(words: 5, fontSize: 14),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Tap hint ──────────────────────────────────────────────
            Center(
              child: Bone(
                width: 180,
                height: 30,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earnings Summary Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class EarningsSummarySkeleton extends StatelessWidget {
  const EarningsSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: _kShimmerEffect,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Bone.square(size: 40, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(width: 12),
                  Expanded(child: Bone.text(words: 2, fontSize: 18)),
                  Bone(
                    width: 90,
                    height: 32,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPeriodCardSkeleton(),
                  const SizedBox(height: 12),
                  _buildPeriodCardSkeleton(),
                  const SizedBox(height: 12),
                  _buildPeriodCardSkeleton(),
                  const SizedBox(height: 12),
                  _buildPeriodCardSkeleton(isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodCardSkeleton({bool isTotal = false}) {
    final double titleFontSize = isTotal ? 16 : 14;
    final double valueFontSize = isTotal ? 20 : 18;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Bone.square(size: 40, borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2, fontSize: titleFontSize),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Bone.text(words: 2, fontSize: valueFontSize),
                    const SizedBox(width: 8),
                    Bone.text(words: 2, fontSize: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class PerformanceSkeleton extends StatelessWidget {
  const PerformanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      effect: _kShimmerEffect,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Bone.square(size: 40, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(width: 12),
                  Bone.text(words: 1, fontSize: 18),
                ],
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── "Overall Statistics" label ──────────────────────
                  Bone.text(words: 2, fontSize: 16),
                  const SizedBox(height: 12),

                  // ── 3 rows × 2 stat-cards ───────────────────────────
                  _buildStatRowSkeleton(),
                  const SizedBox(height: 12),
                  _buildStatRowSkeleton(),
                  const SizedBox(height: 12),
                  _buildStatRowSkeleton(),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Date Range Selector placeholder ──────────────────
                  _buildDateRangeSelectorSkeleton(),

                  const SizedBox(height: 16),

                  // ── "Period Statistics" label ─────────────────────────
                  Bone.text(words: 2, fontSize: 16),
                  const SizedBox(height: 12),

                  // ── 2 rows × 2 stat-cards ───────────────────────────
                  _buildStatRowSkeleton(),
                  const SizedBox(height: 12),
                  _buildStatRowSkeleton(),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Earnings Chart placeholder ────────────────────────
                  _buildChartSkeleton(),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── "Best Performing Areas" label ─────────────────────
                  Bone.text(words: 3, fontSize: 16),
                  const SizedBox(height: 12),
                  _buildAreaCardSkeleton(),
                  _buildAreaCardSkeleton(),
                  _buildAreaCardSkeleton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRowSkeleton() {
    return Row(
      children: [
        Expanded(child: _buildStatCardSkeleton()),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCardSkeleton()),
      ],
    );
  }

  Widget _buildStatCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone.square(size: 20, borderRadius: BorderRadius.circular(4)),
              const SizedBox(width: 8),
              Expanded(child: Bone.text(words: 2, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Bone.text(words: 1, fontSize: 20),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelectorSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone.square(size: 20, borderRadius: BorderRadius.circular(4)),
              const SizedBox(width: 8),
              Bone.text(words: 2, fontSize: 14),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              6,
                  (_) => Bone(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSkeleton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone.square(size: 36, borderRadius: BorderRadius.circular(8)),
              const SizedBox(width: 12),
              Bone.text(words: 3, fontSize: 16),
            ],
          ),
          const SizedBox(height: 16),
          Bone(
            width: double.infinity,
            height: 220,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Bone(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
              const SizedBox(width: 24),
              Bone(width: 70, height: 16, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Bone.square(size: 32, borderRadius: BorderRadius.circular(6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2, fontSize: 14),
                const SizedBox(height: 4),
                Bone.text(words: 4, fontSize: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}