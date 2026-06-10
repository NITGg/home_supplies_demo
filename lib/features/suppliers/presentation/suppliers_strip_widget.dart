import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

import '../../../l10n/app_localizations.dart';
import '../data/models/supplier_models.dart';
import '../manager/supplier_cubit.dart';
import '../manager/supplier_states.dart';
import 'supplier_card.dart';

/// Self-contained horizontal strip of supplier cards.
///
/// Drop it anywhere in a scroll view — it owns its own [SuppliersCubit]
/// and never scrolls independently (uses [shrinkWrap]-style SizedBox height).
///
/// [categoryIds] — when provided, only suppliers that carry at least one of
/// those categories are fetched. Pass every sub-category id when you want
/// suppliers for a parent category (suppliers are linked to leaf categories,
/// not parent ones). Leave empty to fetch all suppliers.
class SuppliersStripWidget extends StatefulWidget {
  final List<int> categoryIds;

  const SuppliersStripWidget({
    super.key,
    this.categoryIds = const [],
  });

  @override
  State<SuppliersStripWidget> createState() => _SuppliersStripWidgetState();
}

class _SuppliersStripWidgetState extends State<SuppliersStripWidget> {
  late final SuppliersCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = SuppliersCubit(categoryIds: widget.categoryIds);
    _cubit.loadSuppliers();
  }

  void _onScrollEnd() => _cubit.loadMore();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _onSupplierTap(SupplierModel supplier) {
    // When the strip is scoped to a single category, pass it through so the
    // supplier detail screen can filter its sections accordingly.
    final filterCategoryId =
    widget.categoryIds.length == 1 ? widget.categoryIds.first : null;

    context.push(
      '/suppliers/${supplier.id}',
      extra: {
        'supplier': supplier,
        'filterCategoryId': filterCategoryId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<SuppliersCubit, SuppliersState>(
        builder: (context, state) {
          return switch (state) {
            SuppliersInitial() ||
            SuppliersLoading() =>
            const _SuppliersStripSkeleton(),
            SuppliersError() =>
            // Silent failure — don't break the page for a non-critical strip.
            const SizedBox.shrink(),
            SuppliersLoaded(:final suppliers) when suppliers.isEmpty =>
            const SizedBox.shrink(),
            SuppliersLoaded(:final suppliers, :final isLoadingMore) =>
              _SuppliersStripContent(
                suppliers: suppliers,
                onTap: _onSupplierTap,
                isLoadingMore: isLoadingMore,
                onScrollEnd: _onScrollEnd,
              ),
          };
        },
      ),
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────────

class _SuppliersStripContent extends StatelessWidget {
  final List<SupplierModel> suppliers;
  final void Function(SupplierModel) onTap;
  final bool isLoadingMore;
  final VoidCallback onScrollEnd;

  const _SuppliersStripContent({
    required this.suppliers,
    required this.onTap,
    required this.isLoadingMore,
    required this.onScrollEnd,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = suppliers.length + (isLoadingMore ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Section label ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.suppliers,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal list ───────────────────────────────────────────────
        SizedBox(
          height: 120,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 120) {
                onScrollEnd();
              }
              return false;
            },
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: itemCount,
              itemBuilder: (_, i) {
                if (i >= suppliers.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return SupplierCard(
                  supplier: suppliers[i],
                  onTap: () => onTap(suppliers[i]),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SuppliersStripSkeleton extends StatefulWidget {
  const _SuppliersStripSkeleton();

  @override
  State<_SuppliersStripSkeleton> createState() =>
      _SuppliersStripSkeletonState();
}

class _SuppliersStripSkeletonState extends State<_SuppliersStripSkeleton>
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Opacity(
              opacity: _anim.value,
              child: Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, __) => AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Opacity(
                opacity: _anim.value,
                child: Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}