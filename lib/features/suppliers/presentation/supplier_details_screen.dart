import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/image_with_fallback.dart';

import '../../../core/widgets/circel_back_button.dart';
import '../../../core/widgets/local_search_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/widgets/cart_button.dart';
import '../../products/data/models/product_model.dart';
import '../../products/presentation/product_card.dart';
import '../data/models/supplier_models.dart';
import '../manager/supplier_details_cubit.dart';
import '../manager/supplier_states.dart';

class SupplierDetailScreen extends StatefulWidget {
  final SupplierModel? supplier;
  final int? supplierId;

  /// When non-null, only this category's section is shown (opened from a
  /// category page). Null means show all categories (opened from home).
  final int? filterCategoryId;

  const SupplierDetailScreen({
    super.key,
    this.supplier,
    this.supplierId,
    this.filterCategoryId,
  }) : assert(supplier != null || supplierId != null);

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late final SupplierDetailCubit _cubit;

  int get _id => widget.supplier?.id ?? widget.supplierId!;

  @override
  void initState() {
    super.initState();
    _cubit = SupplierDetailCubit();
    _cubit.load(_id, filterCategoryId: widget.filterCategoryId);
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
        body: BlocBuilder<SupplierDetailCubit, SupplierDetailState>(
          builder: (context, state) {
            return switch (state) {
              SupplierDetailInitial() || SupplierDetailLoading() =>
                _SupplierLoadingView(supplier: widget.supplier),
              SupplierDetailError(:final message) => _SupplierErrorView(
                message: message,
                supplier: widget.supplier,
                onRetry: () =>
                    _cubit.load(_id, filterCategoryId: widget.filterCategoryId),
              ),
              SupplierDetailLoaded() => _SupplierLoadedView(
                state: state,
                onProductTap: _navigateToProduct,
                onLoadMoreSection: (catId) =>
                    _cubit.loadMoreSectionProducts(_id, catId),
                onRefresh: () => _cubit.refresh(
                  _id,
                  filterCategoryId: widget.filterCategoryId,
                ),
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

class _SupplierLoadedView extends StatefulWidget {
  final SupplierDetailLoaded state;
  final void Function(ProductModel) onProductTap;
  final void Function(int catId) onLoadMoreSection;
  final Future<void> Function() onRefresh;

  const _SupplierLoadedView({
    required this.state,
    required this.onProductTap,
    required this.onLoadMoreSection,
    required this.onRefresh,
  });

  @override
  State<_SupplierLoadedView> createState() => _SupplierLoadedViewState();
}

class _SupplierLoadedViewState extends State<_SupplierLoadedView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  late List<GlobalKey> _sectionKeys;
  int _activePillIndex = 0;
  String _searchQuery = '';
  Timer? _searchDebounce;
  final Map<int, double> _sectionScrollOffsets = {};

  @override
  void initState() {
    super.initState();
    _rebuildKeys(widget.state.sections.length);
    _scrollController.addListener(_onScroll);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _searchQuery) return;
      setState(() => _searchQuery = q);
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 450), () {
        context.read<SupplierDetailCubit>().search(q);
      });
    });
  }

  void _onScroll() {
    _updateSectionOffsetCache();

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
  }

  void _updateSectionOffsetCache() {
    const double stickyHeaders =
        kToolbarHeight + _SupplierPillsHeaderDelegate._height;

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

  void _checkAutoLoad() {
    final screenHeight = MediaQuery.of(context).size.height;
    const loadBuffer = 300.0;
    final sections = widget.state.sections;

    for (int i = 0; i < _sectionKeys.length; i++) {
      final section = sections[i];
      if (!section.hasMore || section.isLoading) continue;

      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final sectionBottomOnScreen = box
          .localToGlobal(Offset(0, box.size.height))
          .dy;

      if (sectionBottomOnScreen < screenHeight + loadBuffer) {
        widget.onLoadMoreSection(section.category.id);
      }
    }
  }

  @override
  void didUpdateWidget(_SupplierLoadedView old) {
    super.didUpdateWidget(old);
    if (old.state.sections.length != widget.state.sections.length) {
      _rebuildKeys(widget.state.sections.length);
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

  void _scrollToSection(int index) async {
    setState(() => _activePillIndex = index);
    const double stickyHeaders =
        kToolbarHeight + _SupplierPillsHeaderDelegate._height;

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

    final double estimatedOffset = _estimatedOffset(index);
    await _scrollController.animateTo(
      estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeIn,
    );

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

  double _estimatedOffset(int index) {
    if (_sectionScrollOffsets.containsKey(index)) {
      return _sectionScrollOffsets[index]!;
    }
    int? before, after;
    for (final key in _sectionScrollOffsets.keys) {
      if (key < index && (before == null || key > before)) before = key;
      if (key > index && (after == null || key < after)) after = key;
    }
    if (before != null && after != null) {
      final t = (index - before) / (after - before);
      return _sectionScrollOffsets[before]! +
          t * (_sectionScrollOffsets[after]! - _sectionScrollOffsets[before]!);
    }
    if (before != null) return _sectionScrollOffsets[before]!;
    if (after != null) return _sectionScrollOffsets[after]!;
    return _scrollController.position.maxScrollExtent;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final visibleSections = state.sections;
    if (_sectionKeys.length != visibleSections.length) {
      _rebuildKeys(visibleSections.length);
    }
    final hasPills = visibleSections.length > 1;

    // No results because the search query returned nothing from the backend
    // (as opposed to the supplier genuinely having no products).
    final allSectionsEmpty = state.sections.isNotEmpty &&
        state.sections.every((s) => !s.isLoading && s.products.isEmpty);
    final noSearchResults = _searchQuery.isNotEmpty && allSectionsEmpty;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      notificationPredicate: (n) => n.depth == 0,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        slivers: [
          // ── Hero app bar ──────────────────────────────────────────────────
          _SupplierSliverAppBar(supplier: state.supplier),

          // ── Working hours banner ──────────────────────────────────────────
          if (state.supplier.workingHours != null &&
              !state.supplier.workingHours!.isAlwaysOpen)
            SliverToBoxAdapter(
              child: _WorkingHoursBanner(supplier: state.supplier),
            ),

          // ── Search bar — filters this supplier's products server-side ─────
          if (state.sections.isNotEmpty)
            SliverToBoxAdapter(
                child: LocalSearchField(
                  controller: _searchCtrl,
                  hintText: l10n.searchProducts,
                  hasQuery: _searchQuery.isNotEmpty,
                ),
            ),

          // ── Sticky category pills ─────────────────────────────────────────
          if (hasPills)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SupplierPillsHeaderDelegate(
                sections: visibleSections,
                activeIndex: _activePillIndex,
                onPillTap: _scrollToSection,
                theme: theme,
              ),
            ),

          // ── Category sections ─────────────────────────────────────────────
          if (state.sections.isEmpty)
            const SliverFillRemaining(child: _EmptySupplierProducts())
          else if (noSearchResults)
            SliverFillRemaining(
              child: _EmptySupplierProducts(message: l10n.noResultsFound),
            )
          else
            SliverList.separated(
              itemCount: visibleSections.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final section = visibleSections[i];
                // Compute supplier open status once — null status means the
                // supplier has no working-hours configured, so default to open.
                final isOpen = state.supplier.currentStatus?.isOpen ?? true;
                return KeyedSubtree(
                  key: _sectionKeys[i],
                  child: _SupplierCategorySectionWidget(
                    section: section,
                    isSupplierOpen: isOpen,
                    onProductTap: widget.onProductTap,
                    onLoadMore: () =>
                        widget.onLoadMoreSection(section.category.id),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Category section inside supplier detail ───────────────────────────────────

class _SupplierCategorySectionWidget extends StatelessWidget {
  final SupplierCategorySection section;
  final void Function(ProductModel) onProductTap;
  final VoidCallback? onLoadMore;
  final bool isSupplierOpen;

  const _SupplierCategorySectionWidget({
    required this.section,
    required this.onProductTap,
    this.onLoadMore,
    this.isSupplierOpen = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return section.products.isEmpty
        ? SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        section.category.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (section.isLoading && section.products.isEmpty)
                _ProductListSkeleton()
              else if (section.products.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.noProductsInSection,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else
                _SupplierProductList(
                  products: section.products.cast<ProductModel>(),
                  isLoadingMore: section.isLoading,
                  hasMore: section.hasMore,
                  isSupplierOpen: isSupplierOpen,
                  onProductTap: onProductTap,
                  onLoadMore: onLoadMore,
                ),
            ],
          );
  }
}

class _SupplierProductList extends StatefulWidget {
  final List<ProductModel> products;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isSupplierOpen;
  final void Function(ProductModel) onProductTap;
  final VoidCallback? onLoadMore;

  const _SupplierProductList({
    required this.products,
    required this.isLoadingMore,
    required this.hasMore,
    this.isSupplierOpen = true,
    required this.onProductTap,
    this.onLoadMore,
  });

  @override
  State<_SupplierProductList> createState() => _SupplierProductListState();
}

class _SupplierProductListState extends State<_SupplierProductList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.products.length + (widget.hasMore ? 1 : 0);

    return SizedBox(
      height: 300,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          if (i == widget.products.length) {
            return const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 48,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            );
          }
          final product = widget.products[i];
          return SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 20),
              child: ProductCard(
                product: product,
                isSupplierOpen: widget.isSupplierOpen,
                onTap: () => widget.onProductTap(product),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductListSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sticky pills ──────────────────────────────────────────────────────────────

class _SupplierPillsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<SupplierCategorySection> sections;
  final int activeIndex;
  final void Function(int) onPillTap;
  final ThemeData theme;

  const _SupplierPillsHeaderDelegate({
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
  bool shouldRebuild(_SupplierPillsHeaderDelegate old) =>
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
            final label = sections[i].category.displayName;
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

class _SupplierSliverAppBar extends StatelessWidget {
  final SupplierModel supplier;

  const _SupplierSliverAppBar({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = supplier.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
      elevation: 0,
      leading: CircleBackButton(onPressed: context.pop),
      actions: [CartButton()],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: _SupplierHeaderBackground(
          supplier: supplier,
          hasPhoto: hasPhoto,
          theme: theme,
        ),
      ),
    );
  }
}

class _SupplierHeaderBackground extends StatelessWidget {
  final SupplierModel supplier;
  final bool hasPhoto;
  final ThemeData theme;

  const _SupplierHeaderBackground({
    required this.supplier,
    required this.hasPhoto,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
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

        // Decorative circle
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

        // Overlay gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.transparent,
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.75),
                ],
              ),
            ),
          ),
        ),

        // Supplier avatar centered
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPhoto
                ? ImageWithIconFallback(
                    imageUrl: supplier.photoUrl!,
                    fit: BoxFit.cover,
                  )
                : _avatarFallback(primary),
          ),
        ),

        // Name & rating at bottom
        Positioned(
          left: 20,
          right: 20,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                supplier.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      blurRadius: 16,
                      color: Colors.black54,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _SupplierRatingRow(rating: supplier.avgRating),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(Color primary) {
    return Container(
      color: HSLColor.fromColor(primary)
          .withLightness(
            (HSLColor.fromColor(primary).lightness - 0.10).clamp(0.0, 1.0),
          )
          .toColor(),
      child: Center(
        child: Text(
          supplier.displayName.isNotEmpty
              ? supplier.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Rating row ────────────────────────────────────────────────────────────────

class _SupplierRatingRow extends StatelessWidget {
  final double rating;

  const _SupplierRatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final roundedRating = (rating * 2).round() / 2; // snap to nearest 0.5
    final filledStars = roundedRating.floor();
    final hasHalf = (roundedRating - filledStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < filledStars
                ? Icons.star_rounded
                : (i == filledStars && hasHalf)
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: const Color(0xFFFFD700),
            size: 18,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
          ),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
        const Text(
          ' / 5',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptySupplierProducts extends StatelessWidget {
  final String? message;

  const _EmptySupplierProducts({this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message ?? AppLocalizations.of(context)!.noProductsInSection,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────

class _SupplierLoadingView extends StatefulWidget {
  final SupplierModel? supplier;

  const _SupplierLoadingView({this.supplier});

  @override
  State<_SupplierLoadingView> createState() => _SupplierLoadingViewState();
}

class _SupplierLoadingViewState extends State<_SupplierLoadingView>
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final shimmer = Colors.black.withOpacity(_pulse.value);
        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
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
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            HSLColor.fromColor(primary)
                                .withLightness(
                                  (HSLColor.fromColor(primary).lightness - 0.12)
                                      .clamp(0.0, 1.0),
                                )
                                .toColor(),
                            primary,
                            HSLColor.fromColor(
                              secondary,
                            ).withSaturation(0.9).toColor(),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: shimmer.withOpacity(0.3),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 24,
                            width: 180,
                            decoration: BoxDecoration(
                              color: shimmer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
                children: List.generate(
                  6,
                  (_) => Container(
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _SupplierErrorView extends StatelessWidget {
  final String message;
  final SupplierModel? supplier;
  final VoidCallback onRetry;

  const _SupplierErrorView({
    required this.message,
    this.supplier,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: supplier != null ? Text(supplier!.displayName) : null,
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

// ── Working hours banner ──────────────────────────────────────────────────────

class _WorkingHoursBanner extends StatelessWidget {
  final SupplierModel supplier;

  const _WorkingHoursBanner({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = supplier.currentStatus!;
    final wh = supplier.workingHours!;
    final theme = Theme.of(context);
    final todaySlots = wh.todaySlots();

    final isOpen = status.isOpen;
    final pillColor = isOpen
        ? const Color(0xFF1DB954)
        : theme.colorScheme.error;
    final pillBg = isOpen
        ? const Color(0xFF1DB954).withOpacity(0.12)
        : theme.colorScheme.errorContainer.withOpacity(0.45);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Main banner row ─────────────────────────────────────────────
          InkWell(
            onTap: () => _showAllHoursSheet(context, wh, theme, l10n),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // ── Open / Closed pill ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pillColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOpen ? l10n.openNow : l10n.closed,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: pillColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── Contextual message ──────────────────────────────────
                  Expanded(
                    child: _StatusMessage(
                      status: status,
                      todaySlots: todaySlots,
                      l10n: l10n,
                      theme: theme,
                    ),
                  ),

                  // ── Chevron ─────────────────────────────────────────────
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),

          // ── "Order delivers tomorrow" nudge ─────────────────────────────
          // Commented out: orders placed outside opening hours are now blocked
          // rather than scheduled, so this notice is no longer shown.
          // if (status.orderDeliveredTomorrow)
          //   _TomorrowNudge(status: status, theme: theme, l10n: l10n),
          Divider(color: Colors.grey.shade200, height: 1),
        ],
      ),
    );
  }

  void _showAllHoursSheet(
    BuildContext context,
    SupplierWorkingHours wh,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllHoursSheet(wh: wh, theme: theme, l10n: l10n),
    );
  }
}

// ── Helpers — time formatting ─────────────────────────────────────────────────

/// Formats an hour/minute pair as a localised time string.
///
/// Arabic uses Eastern Arabic-Indic numerals and the suffixes صباحاً / مساءً.
/// English uses 12-hour format with AM/PM.
String _fmtTime(int hour, int minute, AppLocalizations l10n) {
  final isArabic = l10n.localeName == 'ar';
  final min = minute.toString().padLeft(2, '0');

  if (isArabic) {
    // Convert digits to Eastern Arabic-Indic
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'صباحاً' : 'مساءً';
    return '${_toArabicNumerals('$h12:$min')} $suffix';
  } else {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$min $period';
  }
}

String _toArabicNumerals(String s) {
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = s;
  for (var i = 0; i < en.length; i++) {
    result = result.replaceAll(en[i], ar[i]);
  }
  return result;
}

/// Returns the localised slot range string, e.g. "9:00 AM – 1:00 PM"
/// or "٩:٠٠ صباحاً – ١:٠٠ مساءً".
String _slotRange(WorkingSlot slot, AppLocalizations l10n) {
  final open = _fmtTime(slot.openHour, slot.openMinute, l10n);
  final close = _fmtTime(slot.closeHour, slot.closeMinute, l10n);
  // Use the correct dash direction for RTL/LTR
  final sep = l10n.localeName == 'ar' ? ' – ' : ' – ';
  return '$open$sep$close';
}

/// Returns the localised day name for a JS-style weekday index (0 = Sunday).
String _dayName(int jsDayIndex, AppLocalizations l10n) {
  switch (jsDayIndex) {
    case 0:
      return l10n.daySunday;
    case 1:
      return l10n.dayMonday;
    case 2:
      return l10n.dayTuesday;
    case 3:
      return l10n.dayWednesday;
    case 4:
      return l10n.dayThursday;
    case 5:
      return l10n.dayFriday;
    case 6:
      return l10n.daySaturday;
    default:
      return '';
  }
}

// ── Status message ────────────────────────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  final SupplierStatus status;
  final List<WorkingSlot> todaySlots;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _StatusMessage({
    required this.status,
    required this.todaySlots,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (status.isOpen && status.closingHour != null) {
      return Text(
        l10n.closesAt(
          _fmtTime(status.closingHour!, status.closingMinute ?? 0, l10n),
        ),
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final next = status.nextOpenInfo;
    if (next == null) {
      // No open slot found — show nothing extra beyond the "Closed" pill
      return const SizedBox.shrink();
    }

    final timeStr = _fmtTime(next.openHour, next.openMinute, l10n);

    if (next.isToday) {
      return Text(l10n.opensAt(timeStr), style: base);
    }
    if (next.isTomorrow) {
      return Text(l10n.opensTomorrowAt(timeStr), style: base);
    }
    return Text(
      l10n.opensDayAt(_dayName(next.jsDayIndex, l10n), timeStr),
      style: base,
    );
  }
}

// ── "Order delivers tomorrow" nudge bar ───────────────────────────────────────

class _TomorrowNudge extends StatelessWidget {
  final SupplierStatus status;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _TomorrowNudge({
    required this.status,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final next = status.nextOpenInfo!;
    final timeStr = _fmtTime(next.openHour, next.openMinute, l10n);

    final String whenLabel;
    if (next.isTomorrow) {
      // "tomorrow at 9:00 AM" / "غداً الساعة ٩:٠٠ صباحاً"
      whenLabel = l10n
          .opensTomorrowAt(timeStr)
          .replaceFirst(
            // Strip the leading verb so only "tomorrow at …" remains
            RegExp(r'^(يفتح\s|Opens\s)', caseSensitive: false),
            '',
          );
    } else {
      whenLabel = l10n
          .opensDayAt(_dayName(next.jsDayIndex, l10n), timeStr)
          .replaceFirst(RegExp(r'^(يفتح\s|Opens\s)', caseSensitive: false), '');
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 15,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              l10n.orderDeliveredTomorrowNotice(whenLabel),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full weekly hours bottom sheet ────────────────────────────────────────────

class _AllHoursSheet extends StatelessWidget {
  final SupplierWorkingHours wh;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _AllHoursSheet({
    required this.wh,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final jsToday = wh.currentJsDay();
    final allDays = wh.allDays();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.workingHours,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey.shade200),

            // ── Day rows ────────────────────────────────────────────────
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: allDays.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (_, i) {
                final day = allDays[i];
                return _DayRow(
                  dayName: _dayName(day.jsDay, l10n),
                  isClosed: day.isClosed,
                  slots: day.slots,
                  isToday: day.jsDay == jsToday,
                  theme: theme,
                  l10n: l10n,
                );
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Day row ───────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String dayName;
  final bool isClosed;
  final List<WorkingSlot> slots;
  final bool isToday;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _DayRow({
    required this.dayName,
    required this.isClosed,
    required this.slots,
    required this.isToday,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final todayBg = isToday
        ? theme.colorScheme.primaryContainer.withOpacity(0.35)
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: todayBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Day name ────────────────────────────────────────────────
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Hours ───────────────────────────────────────────────────
          Expanded(
            child: isClosed || slots.isEmpty
                ? Text(
                    l10n.closed,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: slots
                        .map(
                          (s) => Text(
                            _slotRange(s, l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
