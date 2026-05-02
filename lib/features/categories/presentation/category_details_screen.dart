import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/features/categories/presentation/sub_cat_section.dart';

import '../../../core/widgets/circel_back_button.dart';
import '../../../core/widgets/image_with_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/widgets/cart_icon.dart';
import '../../products/data/models/product_model.dart';
import '../../search/presentation/search_dialog.dart';
import '../../suppliers/presentation/main_supplier_hours_banner.dart';
import '../../suppliers/presentation/suppliers_strip_widget.dart';
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
                  _LoadingView(category: widget.category),
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

  // One GlobalKey per section — used to measure positions for scrolling.
  late List<GlobalKey> _sectionKeys;
  int _activePillIndex = 0;

  /// Absolute scroll offset of each section's top edge, updated continuously
  /// as the user scrolls. Used as a fallback when a section hasn't been
  /// rendered yet (SliverList lazy-builds items off-screen).
  final Map<int, double> _sectionScrollOffsets = {};

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
    _scrollController.addListener(_onScroll);
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

    for (int i = 0; i < _sectionKeys.length; i++) {
      final section = widget.state.sections[i];
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
    if (old.state.sections.length != widget.state.sections.length) {
      _rebuildKeys();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildKeys() {
    _sectionKeys = List.generate(
      widget.state.sections.length,
          (_) => GlobalKey(),
    );
    // Stale offsets are invalid after a rebuild — clear them so we never
    // jump to a wrong position.
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
    final hasPills = state.hasSections && state.sections.length > 1;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      notificationPredicate: (notification) => notification.depth == 0,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        slivers: [
          // ── Hero app bar ──────────────────────────────────────────────────
          _CategorySliverAppBar(category: state.category),
          SliverToBoxAdapter(
            child: state.mainSupplier != null
                ? MainSupplierWorkingHoursBanner(supplier: state.mainSupplier!)
                : const SizedBox.shrink(),
          ),
          SliverToBoxAdapter(
            child: SuppliersStripWidget(
              categoryIds: state.hasSections
                  ? state.sections.map((s) => s.subCategory.id).toList()
                  : [state.category.id],
            ),
          ),
          // ── Sticky pills row (only when there are multiple sections) ──────
          if (hasPills)
            SliverPersistentHeader(
              pinned: true,
              delegate: _PillsHeaderDelegate(
                sections: state.sections,
                activeIndex: _activePillIndex,
                onPillTap: _scrollToSection,
                theme: theme,
              ),
            ),

          // ── Content ───────────────────────────────────────────────────────
          if (state.hasSections)
            SliverList.separated(
              itemCount: state.sections.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final section = state.sections[i];
                // Inherit the main supplier's open/closed status so product
                // cards block the cart when the supplier is closed.
                final isOpen =
                    state.mainSupplier?.currentStatus?.isOpen ?? true;
                return KeyedSubtree(
                  key: _sectionKeys[i],
                  child: SubCategorySectionWidget(
                    section: section,
                    isSupplierOpen: isOpen,
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
                  ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
                  : state.directProducts.isEmpty
                  ? const _EmptyProducts()
                  : DirectProductsGrid(
                products: state.directProducts,
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
            : theme.colorScheme.surfaceVariant,
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
      actions: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          child: IconButton(
            icon: Icon(Icons.search_rounded, color: Colors.grey.shade700),
            onPressed: () {
              showSearchDialog(context);
            },
            padding: EdgeInsets.zero,
          ),
        ),
        AnimatedCartIcon(onTap: () => context.push('/cart')),
      ],
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

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

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
            AppLocalizations.of(context)!.noProductsInSection,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  final CategoryModel? category;

  const _LoadingView({this.category});

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.06,
      end: 0.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final shimmer = Colors.black.withOpacity(_pulse.value);
        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            if (widget.category != null)
              _CategorySliverAppBar(category: widget.category!)
            else
              _GradientPlaceholderAppBar(shimmer: shimmer),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
                children: List.generate(
                  6,
                      (_) => _SkeletonProductCard(shimmer: shimmer),
                ),
              ),
            ),
          ],
        );
      },
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
      actions: [AnimatedCartIcon(onTap: () => context.push('/cart'))],
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

class _SkeletonProductCard extends StatelessWidget {
  final Color shimmer;

  const _SkeletonProductCard({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: shimmer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Container(
                    height: 10,
                    width: 55,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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