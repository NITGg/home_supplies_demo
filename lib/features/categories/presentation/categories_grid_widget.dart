import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  State<CategoriesGridWidget> createState() => _CategoriesGridWidgetState();
}

class _CategoriesGridWidgetState extends State<CategoriesGridWidget> {
  late final CategoriesCubit _cubit;

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

  /// Threshold: above this count the compact (circle chip) style is used.
  static const int _compactThreshold = 8;

  const _CategoriesSection({
    required this.state,
    required this.onCategoryTap,
    required this.onLoadMore,
  });

  bool get _useCompact => state.totalCount > _compactThreshold;

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
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'التصنيفات',
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

        // ── Grid ───────────────────────────────────────────────────────────
        if (_useCompact)
          _CompactScrollRow(
            categories: state.categories,
            onTap: onCategoryTap,
            hasMore: state.hasMore,
            onLoadMore: onLoadMore,
          )
        else
          _RegularWrappedGrid(
            categories: state.categories,
            onTap: onCategoryTap,
          ),

        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact: horizontal scrollable row of circle chips
// ─────────────────────────────────────────────────────────────────────────────

class _CompactScrollRow extends StatelessWidget {
  final List<CategoryModel> categories;
  final void Function(CategoryModel) onTap;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _CompactScrollRow({
    required this.categories,
    required this.onTap,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 40 &&
            hasMore) {
          onLoadMore();
        }
        return false;
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: categories
              .map(
                (cat) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CategoryCard(
                category: cat,
                onTap: () => onTap(cat),
                style: CategoryCardStyle.compact,
              ),
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Regular: wrapped grid (shrinkWrap — no independent scroll)
// ─────────────────────────────────────────────────────────────────────────────

class _RegularWrappedGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final void Function(CategoryModel) onTap;

  const _RegularWrappedGrid({
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 700 ? 4 : 3;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: categories.length,
          itemBuilder: (_, i) => CategoryCard(
            category: categories[i],
            onTap: () => onTap(categories[i]),
            style: CategoryCardStyle.regular,
          ),
        );
      },
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
        // Skeleton title bar
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
        // Skeleton circle row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: List.generate(
              6,
                  (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => Opacity(
                    opacity: _anim.value,
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 50,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
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