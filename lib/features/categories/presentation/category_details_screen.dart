import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/features/categories/presentation/sub_cat_section.dart';

import '../../../core/widgets/circel_back_button.dart';
import '../../../core/widgets/image_with_fallback.dart';
import '../../../core/widgets/local_search_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/widgets/cart_button.dart';
import '../../products/data/models/product_model.dart';
import '../../suppliers/data/models/supplier_models.dart';
import '../../suppliers/presentation/supplier_card.dart';
import '../data/models/category_models.dart';
import '../manager/category_detail_cubit.dart';
import '../manager/category_detail_states.dart';

class CategoryDetailScreen extends StatefulWidget {
  final CategoryModel? category;
  final int? categoryId;

  const CategoryDetailScreen({super.key, this.category, this.categoryId})
    : assert(category != null || categoryId != null);

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late final CategoryDetailCubit _cubit;

  int get _id => widget.category?.id ?? widget.categoryId!;

  @override
  void initState() {
    super.initState();
    _cubit = CategoryDetailCubit();
    _cubit.load(_id);
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
      child: Scaffold(
        body: BlocBuilder<CategoryDetailCubit, CategoryDetailState>(
          builder: (context, state) {
            return switch (state) {
              CategoryDetailInitial() || CategoryDetailLoading() =>
                _InitialShimmerView(category: widget.category),
              CategoryDetailError(:final message) => _ErrorView(
                message: message,
                category: widget.category,
                onRetry: () => _cubit.load(_id),
              ),
              CategoryDetailLoaded() => _LoadedView(
                state: state,
                onProductTap: _navigateToProduct,
                onLoadMoreSection: _cubit.loadMoreSectionProducts,
                onLoadMoreDirect: _cubit.loadMoreDirectProducts,
                onRefresh: () => _cubit.refresh(_id),
              ),
            };
          },
        ),
      ),
    );
  }

  void _navigateToProduct(ProductModel product) {
    context.push('/products/${product.id}', extra: product);
  }
}

// ── Loaded View ───────────────────────────────────────────────────────────────

class _LoadedView extends StatefulWidget {
  final CategoryDetailLoaded state;
  final void Function(ProductModel) onProductTap;
  final void Function(int subCatId) onLoadMoreSection;
  final VoidCallback onLoadMoreDirect;
  final Future<void> Function() onRefresh;

  const _LoadedView({
    required this.state,
    required this.onProductTap,
    required this.onLoadMoreSection,
    required this.onLoadMoreDirect,
    required this.onRefresh,
  });

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  // One GlobalKey per section — used to measure positions for scrolling.
  late List<GlobalKey> _sectionKeys;
  int _activePillIndex = 0;
  String _searchQuery = '';
  Timer? _searchDebounce;

  /// Absolute scroll offset of each section's top edge, updated continuously
  /// as the user scrolls. Used as a fallback when a section hasn't been
  /// rendered yet (SliverList lazy-builds items off-screen).
  final Map<int, double> _sectionScrollOffsets = {};

  @override
  void initState() {
    super.initState();
    _rebuildKeys(widget.state.sectionsWithProducts.length);
    _scrollController.addListener(_onScroll);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _searchQuery) return;
      setState(() => _searchQuery = q);
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 450), () {
        context.read<CategoryDetailCubit>().search(q);
      });
    });
  }

  // ── Scroll listener — updates the active pill and offset cache ────────────
  void _onScroll() {
    // ── cache absolute offsets for all currently-rendered sections ────────
    _updateSectionOffsetCache();

    // ── update active pill ─────────────────────────────────────────────
    if (_sectionKeys.isNotEmpty) {
      const threshold = 180.0;
      for (int i = _sectionKeys.length - 1; i >= 0; i--) {
        final ctx = _sectionKeys[i].currentContext;
        if (ctx == null) continue;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null) continue;
        final dy = box.localToGlobal(Offset.zero).dy;
        if (dy <= threshold) {
          if (_activePillIndex != i) setState(() => _activePillIndex = i);
          break;
        }
      }
    }

    _checkAutoLoad();
    _checkAutoLoadDirect();
  }

  /// Records the absolute scroll offset of every currently-rendered section
  /// so we can jump to them later even when they scroll off-screen.
  void _updateSectionOffsetCache() {
    const double stickyHeaders = kToolbarHeight + _PillsHeaderDelegate._height;

    for (int i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final screenDy = box.localToGlobal(Offset.zero).dy;
      _sectionScrollOffsets[i] =
          (_scrollController.offset + screenDy - stickyHeaders).clamp(
            0.0,
            double.maxFinite,
          );
    }
  }

  void _checkAutoLoadDirect() {
    final state = widget.state;
    if (state.hasSections) return;
    if (!state.directProductsHasMore || state.directProductsLoading) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      debugPrint('🔄 Loading more direct products');
      widget.onLoadMoreDirect();
    }
  }

  void _checkAutoLoad() {
    final screenHeight = MediaQuery.of(context).size.height;
    const loadBuffer = 300.0;
    final visible = widget.state.sectionsWithProducts;

    for (int i = 0; i < _sectionKeys.length; i++) {
      final section = visible[i];
      if (!section.hasMore || section.isLoading) continue;

      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final sectionBottomOnScreen = box
          .localToGlobal(Offset(0, box.size.height))
          .dy;

      if (sectionBottomOnScreen < screenHeight + loadBuffer) {
        widget.onLoadMoreSection(section.subCategory.id);
      }
    }
  }

  @override
  void didUpdateWidget(_LoadedView old) {
    super.didUpdateWidget(old);
    final oldVisible = old.state.sectionsWithProducts.length;
    final newVisible = widget.state.sectionsWithProducts.length;
    if (oldVisible != newVisible) {
      _rebuildKeys(newVisible);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _rebuildKeys(int length) {
    _sectionKeys = List.generate(length, (_) => GlobalKey());
    _sectionScrollOffsets.clear();
  }

  // ── Scroll to section when a pill is tapped ───────────────────────────────

  /// Scroll the list so [index] lands just below the sticky headers.
  ///
  /// SliverList only builds items when they enter the viewport, so the target
  /// section may not have a RenderObject yet.  We handle this with two passes:
  ///
  /// Pass 1 – jump to a known/estimated offset so Flutter builds the item.
  /// Pass 2 – in the very next frame the RenderObject is available; we read
  ///           its exact position and animate to it.
  void _scrollToSection(int index) async {
    setState(() => _activePillIndex = index);

    const double stickyHeaders = kToolbarHeight + _PillsHeaderDelegate._height;

    // ── Pass 1 (direct): item already rendered ────────────────────────────
    final ctx = _sectionKeys[index].currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final screenDy = box.localToGlobal(Offset.zero).dy;
      final target = (_scrollController.offset + screenDy - stickyHeaders)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    // ── Pass 1 (lazy): item is off-screen ─────────────────────────────────
    // Scroll to the best estimate so Flutter builds the SliverList item.
    final double estimatedOffset = _estimatedOffset(index);
    await _scrollController.animateTo(
      estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeIn,
    );

    // ── Pass 2: item is now rendered — animate to exact position ──────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx2 = _sectionKeys[index].currentContext;
      if (ctx2 == null) return;
      final box = ctx2.findRenderObject() as RenderBox?;
      if (box == null) return;
      final screenDy = box.localToGlobal(Offset.zero).dy;
      final target = (_scrollController.offset + screenDy - stickyHeaders)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Returns the best absolute scroll-offset estimate for [index] when the
  /// section hasn't been rendered yet.
  ///
  /// Priority:
  ///   1. A directly cached offset for [index].
  ///   2. Linear interpolation between the two nearest cached neighbours.
  ///   3. The single nearest cached neighbour (before or after).
  ///   4. `maxScrollExtent` as a last resort (forces all items to render).
  double _estimatedOffset(int index) {
    // 1. Direct cache hit.
    if (_sectionScrollOffsets.containsKey(index)) {
      return _sectionScrollOffsets[index]!;
    }

    // 2. Find the nearest cached neighbours on each side.
    int? before, after;
    for (final key in _sectionScrollOffsets.keys) {
      if (key < index && (before == null || key > before)) before = key;
      if (key > index && (after == null || key < after)) after = key;
    }

    if (before != null && after != null) {
      // Linear interpolation between the two neighbours.
      final t = (index - before) / (after - before);
      return _sectionScrollOffsets[before]! +
          t * (_sectionScrollOffsets[after]! - _sectionScrollOffsets[before]!);
    }
    if (before != null) return _sectionScrollOffsets[before]!;
    if (after != null) return _sectionScrollOffsets[after]!;

    // 4. No cached data at all — scroll to the bottom to force rendering.
    return _scrollController.position.maxScrollExtent;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Only show pills for sections that actually have products, so empty
    // sub-categories never appear as navigation targets.
    final visibleSections = state.sectionsWithProducts;
    if (_sectionKeys.length != visibleSections.length) {
      _rebuildKeys(visibleSections.length);
    }
    final hasPills = visibleSections.length > 1;

    // Show shimmer while all sections are still loading and none has products
    // yet — avoids the flickering "each section loads then disappears" effect.
    final showSectionShimmer =
        state.hasSections && state.anySectionLoading && !state.hasAnyProducts;

    // The search field is only useful once the category's products have
    // loaded at least once.
    final showSearchBar = state.hasSections
        ? !showSectionShimmer
        : !(state.directProductsLoading && state.directProducts.isEmpty);

    // No results because the search query returned nothing from the backend
    // (as opposed to the section/category genuinely having no products).
    final noSearchResults = _searchQuery.isNotEmpty &&
        (state.hasSections
            ? state.allSectionsEmpty
            : !state.directProductsLoading && state.directProducts.isEmpty);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      notificationPredicate: (notification) => notification.depth == 0,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        slivers: [
          // ── Hero app bar ────────────────────────────────────────────────
          _CategorySliverAppBar(category: state.category),
          if (state.suppliersReady && state.suppliers.isNotEmpty)
            SliverToBoxAdapter(
              child: _CategorySuppliersStrip(
                suppliers: state.suppliers,
                onTap: (supplier) => context.push(
                  '/suppliers/${supplier.id}',
                  extra: {'supplier': supplier, 'filterCategoryId': null},
                ),
              ),
            ),

          // ── Search bar — filters this category's products server-side ─────
          if (showSearchBar)
            SliverToBoxAdapter(
                child: LocalSearchField(
                  controller: _searchCtrl,
                  hintText: l10n.searchProducts,
                  hasQuery: _searchQuery.isNotEmpty,
              ),
            ),

          // ── Sticky pills (only sections with products) ───────────────────
          if (hasPills && !showSectionShimmer)
            SliverPersistentHeader(
              pinned: true,
              delegate: _PillsHeaderDelegate(
                sections: visibleSections,
                activeIndex: _activePillIndex,
                onPillTap: _scrollToSection,
                theme: theme,
              ),
            ),

          // ── Content ──────────────────────────────────────────────────────
          if (showSectionShimmer)
            // Still loading: show a full-page shimmer instead of partial skeletons
            const SliverToBoxAdapter(child: _SectionsShimmer())
          else if (noSearchResults)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyProducts(message: l10n.noResultsFound),
            )
          else if (state.allSectionsEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyProducts(),
            )
          else if (state.hasSections)
            // Only list sections that have products
            SliverList.separated(
              itemCount: visibleSections.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final section = visibleSections[i];
                return KeyedSubtree(
                  key: _sectionKeys[i],
                  child: SubCategorySectionWidget(
                    section: section,
                    suppliersById: state.suppliersById,
                    onProductTap: widget.onProductTap,
                    onLoadMore: () =>
                        widget.onLoadMoreSection(section.subCategory.id),
                  ),
                );
              },
            )
          else
            SliverToBoxAdapter(
              child: state.directProductsLoading && state.directProducts.isEmpty
                  ? const _DirectProductsShimmer()
                  : state.directProducts.isEmpty
                  ? const _EmptyProducts()
                  : DirectProductsGrid(
                      products: state.directProducts,
                      suppliersById: state.suppliersById,
                      isLoadingMore: state.directProductsLoading,
                      hasMore: state.directProductsHasMore,
                      onProductTap: widget.onProductTap,
                      onLoadMore: widget.onLoadMoreDirect,
                    ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Sticky pills header delegate ──────────────────────────────────────────────

class _PillsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<dynamic> sections; // CategorySectionState or similar
  final int activeIndex;
  final void Function(int) onPillTap;
  final ThemeData theme;

  const _PillsHeaderDelegate({
    required this.sections,
    required this.activeIndex,
    required this.onPillTap,
    required this.theme,
  });

  static const double _height = 52.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_PillsHeaderDelegate old) =>
      old.activeIndex != activeIndex || old.sections.length != sections.length;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final elevated = overlapsContent || shrinkOffset > 0;

    return Material(
      color: theme.colorScheme.surface,
      elevation: elevated ? 2 : 0,
      shadowColor: Colors.black.withOpacity(0.10),
      child: SizedBox(
        height: _height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: sections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final isActive = i == activeIndex;
            final label = sections[i].subCategory.displayName as String? ?? '';

            return _PillChip(
              label: label,
              isActive: isActive,
              theme: theme,
              onTap: () => onPillTap(i),
            );
          },
        ),
      ),
    );
  }
}

// ── Individual pill chip ──────────────────────────────────────────────────────

class _PillChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final ThemeData theme;
  final VoidCallback onTap;

  const _PillChip({
    required this.label,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withOpacity(0.35),
                width: 0.8,
              ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: theme.textTheme.labelMedium!.copyWith(
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sliver app bar ────────────────────────────────────────────────────────────

class _CategorySliverAppBar extends StatelessWidget {
  final CategoryModel category;

  const _CategorySliverAppBar({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = category.imageUrl != null && category.imageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
      elevation: 0,
      leading: CircleBackButton(),
      actions: [CartButton()],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: _HeaderBackground(
          category: category,
          hasImage: hasImage,
          theme: theme,
        ),
      ),
    );
  }
}

// ── Header background ─────────────────────────────────────────────────────────

class _HeaderBackground extends StatelessWidget {
  final CategoryModel category;
  final bool hasImage;
  final ThemeData theme;

  const _HeaderBackground({
    required this.category,
    required this.hasImage,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          ImageWithIconFallback(imageUrl: category.imageUrl!, fit: BoxFit.cover)
        else
          _GradientMesh(theme: theme, category: category),

        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Colors.black.withOpacity(0.12),
                  Colors.transparent,
                  Colors.black.withOpacity(0.50),
                  Colors.black.withOpacity(0.80),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 20,
          right: 20,
          bottom: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (category.parentId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 11,
                        color: Colors.white.withOpacity(0.82),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.subCategory,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                category.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.8,
                  shadows: [
                    Shadow(
                      blurRadius: 16,
                      color: Colors.black54,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
              if (category.displayDescription.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  category.displayDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Gradient mesh (no-image fallback) ────────────────────────────────────────

class _GradientMesh extends StatelessWidget {
  final ThemeData theme;
  final CategoryModel category;

  const _GradientMesh({required this.theme, required this.category});

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                HSLColor.fromColor(primary)
                    .withLightness(
                      (HSLColor.fromColor(primary).lightness - 0.12).clamp(
                        0.0,
                        1.0,
                      ),
                    )
                    .toColor(),
                primary,
                HSLColor.fromColor(secondary).withSaturation(0.9).toColor(),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withOpacity(0.12), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          right: -8,
          bottom: -24,
          child: Text(
            category.displayName.isNotEmpty
                ? category.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: 210,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.07),
              height: 1,
            ),
          ),
        ),
        if (category.iconUrl != null && category.iconUrl!.isNotEmpty)
          Center(
            child: Opacity(
              opacity: 0.12,
              child: Image.network(
                category.iconUrl!,
                width: 130,
                height: 130,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

// ── Full-page shimmer shown while all sections are loading ────────────────────

class _SectionsShimmer extends StatefulWidget {
  const _SectionsShimmer();

  @override
  State<_SectionsShimmer> createState() => _SectionsShimmerState();
}

class _SectionsShimmerState extends State<_SectionsShimmer>
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
    _anim = Tween<double>(begin: 0.3, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = Colors.grey.shade300.withOpacity(_anim.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (s) => _ShimmerSection(color: shimmer)),
        );
      },
    );
  }
}

class _ShimmerSection extends StatelessWidget {
  final Color color;
  const _ShimmerSection({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4, height: 20,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 120, height: 16,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
        // Horizontal product card skeletons
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Colors.grey.shade200, height: 1),
        ),
      ],
    );
  }
}

// ── Grid shimmer for direct-products (leaf) categories ───────────────────────

class _DirectProductsShimmer extends StatefulWidget {
  const _DirectProductsShimmer();

  @override
  State<_DirectProductsShimmer> createState() => _DirectProductsShimmerState();
}

class _DirectProductsShimmerState extends State<_DirectProductsShimmer>
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
    _anim = Tween<double>(begin: 0.3, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Colors.grey.shade300.withOpacity(_anim.value);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: crossAxisCount == 3 ? 400 : 300,
            ),
            itemCount: 6,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Empty products ────────────────────────────────────────────────────────────

class _EmptyProducts extends StatelessWidget {
  final String? message;

  const _EmptyProducts({this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message ?? AppLocalizations.of(context)!.noProductsInSection,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ── Category suppliers strip (reads from state, no extra API call) ────────────

class _CategorySuppliersStrip extends StatelessWidget {
  final List<SupplierModel> suppliers;
  final void Function(SupplierModel) onTap;

  const _CategorySuppliersStrip({
    required this.suppliers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
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
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: suppliers.length,
            itemBuilder: (_, i) => SupplierCard(
              supplier: suppliers[i],
              onTap: () => onTap(suppliers[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────

/// Initial loading view — uses the same shimmer style as the loaded-but-still-
/// fetching phase so there is only one consistent shimmer from tap to content.
class _InitialShimmerView extends StatelessWidget {
  final CategoryModel? category;

  const _InitialShimmerView({this.category});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        if (category != null)
          _CategorySliverAppBar(category: category!)
        else
          _GradientPlaceholderAppBar(
            shimmer: Colors.black.withOpacity(0.10),
          ),
        const SliverToBoxAdapter(child: _SectionsShimmer()),
      ],
    );
  }
}

// ── Gradient placeholder app bar ──────────────────────────────────────────────

class _GradientPlaceholderAppBar extends StatelessWidget {
  final Color shimmer;

  const _GradientPlaceholderAppBar({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Colors.grey.shade700,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      actions: [CartButton()],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    HSLColor.fromColor(primary)
                        .withLightness(
                          (HSLColor.fromColor(primary).lightness - 0.12).clamp(
                            0.0,
                            1.0,
                          ),
                        )
                        .toColor(),
                    primary,
                    HSLColor.fromColor(secondary).withSaturation(0.9).toColor(),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.70, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.12),
                      Colors.transparent,
                      Colors.black.withOpacity(0.50),
                      Colors.black.withOpacity(0.80),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 32,
                    width: 200,
                    decoration: BoxDecoration(
                      color: shimmer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 13,
                    width: 140,
                    decoration: BoxDecoration(
                      color: shimmer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton product card ─────────────────────────────────────────────────────


// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final CategoryModel? category;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    this.category,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: category != null ? Text(category!.displayName) : null,
          pinned: true,
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context)!.refresh),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
