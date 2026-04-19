import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

import '../../../l10n/app_localizations.dart';
import '../data/models/category_models.dart';
import '../manager/category_cubit.dart';
import '../manager/category_states.dart';
import 'category_card.dart';

/// A self-contained, embeddable categories section.
///
/// Owns its own [CategoriesCubit] — just drop it anywhere and it loads itself.
/// Never scrolls independently: compact style uses a [SingleChildScrollView]
/// row, regular style uses a [GridView] with [shrinkWrap] so the parent
/// scroll view stays in control.
class CategoriesGridWidget extends StatefulWidget {
  final void Function(CategoryModel category) onCategoryTap;

  /// How many items to request per page.
  final int pageSize;

  const CategoriesGridWidget({
    super.key,
    required this.onCategoryTap,
    this.pageSize = 30,
  });

  @override
  State<CategoriesGridWidget> createState() => CategoriesGridWidgetState();
}

class CategoriesGridWidgetState extends State<CategoriesGridWidget> {
  late final CategoriesCubit _cubit;

  Future<void> refresh() => _cubit.loadCategories(refresh: true);

  @override
  void initState() {
    super.initState();
    _cubit = CategoriesCubit();
    _cubit.loadCategories();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          return switch (state) {
            CategoriesInitial() || CategoriesLoading() =>
            const _CategoriesSkeletonRow(),
            CategoriesError() => const SizedBox.shrink(),
            CategoriesLoaded() => _CategoriesSection(
              state: state,
              onCategoryTap: widget.onCategoryTap,
              onLoadMore: _cubit.loadMore,
            ),
          };
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section wrapper (title + adaptive grid)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesSection extends StatelessWidget {
  final CategoriesLoaded state;
  final void Function(CategoryModel) onCategoryTap;
  final VoidCallback onLoadMore;

  const _CategoriesSection({
    required this.state,
    required this.onCategoryTap,
    required this.onLoadMore,
  });

  // ≤6 → 3 columns regular, >6 → 4-5 columns compact
  bool get _useCompact => state.totalCount > 2;

  int get _crossAxisCount {
    if (!_useCompact) return 3;
    if (state.totalCount > 12) return 5;
    return 4;
  }

  double get _childAspectRatio => _useCompact ? 0.95 : 0.82;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.categories,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (state.isLoadingMore)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),

        // ── Always a grid, compact style when many ──────────────────────
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 40 &&
                state.hasMore) {
              onLoadMore();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: _childAspectRatio,
            ),
            itemCount: state.categories.length,
            itemBuilder: (_, i) => CategoryCard(
              category: state.categories[i],
              onTap: () => onCategoryTap(state.categories[i]),
              style: _useCompact
                  ? CategoryCardStyle.compact
                  : CategoryCardStyle.regular,
            ),
          ),
        ),

        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton row (shown while loading)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesSkeletonRow extends StatefulWidget {
  const _CategoriesSkeletonRow();

  @override
  State<_CategoriesSkeletonRow> createState() => _CategoriesSkeletonRowState();
}

class _CategoriesSkeletonRowState extends State<_CategoriesSkeletonRow>
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
    _anim = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
        // ── Skeleton header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Opacity(
              opacity: _anim.value,
              child: Container(
                width: 90,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),

        // ── Skeleton grid (4 columns compact — matches most common layout) ─
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemCount: 8,
            itemBuilder: (_, __) => AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Opacity(
                opacity: _anim.value,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}