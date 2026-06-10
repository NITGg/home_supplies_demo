import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/style/text_styles.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/widgets/cart_button.dart';
import '../../categories/data/models/category_models.dart';
import '../../categories/data/repo/category_repo.dart';
import '../../categories/presentation/sub_cat_section.dart';
import '../data/models/product_model.dart';
import '../data/models/product_response_model.dart';

typedef ProductsFetcher = Future<ProductsResponseModel> Function({
required int skip,
required int limit,
int? categoryId,
String? keyword,
});

enum _SortOption { none, priceLow, priceHigh, discount }

class FilterableBulkProductScreen extends StatefulWidget {
  final String title;
  final ProductsFetcher fetcher;

  /// Show the "Highest Discount" sort chip — only meaningful on the offered screen.
  final bool showDiscountSort;

  const FilterableBulkProductScreen({
    super.key,
    required this.title,
    required this.fetcher,
    this.showDiscountSort = false,
  });

  @override
  State<FilterableBulkProductScreen> createState() =>
      _FilterableBulkProductScreenState();
}

class _FilterableBulkProductScreenState
    extends State<FilterableBulkProductScreen> {
  static const int _pageSize = 10;

  final CategoryRepository _categoryRepo = CategoryRepositoryImpl();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ProductModel> _products = [];

  /// All categories fetched from the API (fetched once).
  List<CategoryModel> _allCategories = [];

  /// Category IDs that have appeared in at least one loaded product.
  Set<int> _seenCategoryIds = {};

  Timer? _debounce;

  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  bool _initialLoadDone = false;

  int? _selectedCategoryId;
  _SortOption _sortOption = _SortOption.none;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _searchQuery) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 450), () {
        setState(() {
          _searchQuery = q;
          _products = [];
          _skip = 0;
          _hasMore = true;
          _initialLoadDone = false;
        });
        _load();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _load();
    }
  }

  /// Fetches all categories once, then keeps [_seenCategoryIds] in sync with
  /// the categoryIds that actually appear in [_products].
  Future<void> _syncCategories() async {
    // Collect unique categoryIds from all loaded products.
    final ids = _products.map((p) => p.categoryId).toSet();

    // Nothing new to handle.
    if (ids == _seenCategoryIds) return;

    try {
      // Fetch the full category list only on the first call.
      if (_allCategories.isEmpty) {
        final result = await _categoryRepo.getCategories(limit: 100);
        if (!mounted) return;
        setState(() => _allCategories = result.categories);
      }

      // Update the set of seen IDs so the chip list rebuilds.
      if (mounted) setState(() => _seenCategoryIds = ids);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final response = await widget.fetcher(
        skip: _skip,
        limit: _pageSize,
        categoryId: _selectedCategoryId,
        keyword: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _products = [..._products, ...response.products];
        _skip += response.products.length;
        _hasMore = _skip < response.totalProducts;
        _isLoading = false;
        _initialLoadDone = true;
      });
      // Sync category chips after products are updated.
      await _syncCategories();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initialLoadDone = true;
      });
    }
  }

  void _selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _products = [];
      _skip = 0;
      _hasMore = true;
      _initialLoadDone = false;
      // Keep _allCategories and _seenCategoryIds — they'll be rebuilt by
      // _syncCategories after the next page loads.
      _seenCategoryIds = {};
    });
    _load();
  }

  List<ProductModel> get _displayProducts {
    var list = List<ProductModel>.from(_products);

    switch (_sortOption) {
      case _SortOption.priceLow:
        list.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case _SortOption.priceHigh:
        list.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
      case _SortOption.discount:
        list.sort((a, b) =>
            (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));
      case _SortOption.none:
        break;
    }

    return list;
  }

  /// Only the categories whose IDs actually appear in the loaded products.
  List<CategoryModel> get _visibleCategories => _allCategories
      .where((cat) => _seenCategoryIds.contains(cat.id))
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayed = _displayProducts;
    final visibleCategories = _visibleCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: CircleBackButton(),
        elevation: 0,
        actions: [CartButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.searchProducts,
                hintStyle: AppTextStyles.regular14.copyWith(color: Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _searchCtrl.clear,
                )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ),
            ),
          ),

          // ── Sort chips ────────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Text(
                  '${l10n.sortBy}:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: l10n.priceLowToHigh,
                  icon: Icons.arrow_upward_rounded,
                  selected: _sortOption == _SortOption.priceLow,
                  onTap: () => setState(() {
                    _sortOption = _sortOption == _SortOption.priceLow
                        ? _SortOption.none
                        : _SortOption.priceLow;
                  }),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: l10n.priceHighToLow,
                  icon: Icons.arrow_downward_rounded,
                  selected: _sortOption == _SortOption.priceHigh,
                  onTap: () => setState(() {
                    _sortOption = _sortOption == _SortOption.priceHigh
                        ? _SortOption.none
                        : _SortOption.priceHigh;
                  }),
                ),
                if (widget.showDiscountSort) ...[
                  const SizedBox(width: 6),
                  _SortChip(
                    label: l10n.highestDiscount,
                    icon: Icons.local_offer_rounded,
                    selected: _sortOption == _SortOption.discount,
                    onTap: () => setState(() {
                      _sortOption = _sortOption == _SortOption.discount
                          ? _SortOption.none
                          : _SortOption.discount;
                    }),
                  ),
                ],
              ],
            ),
          ),

          // ── Category filter chips — only categories present in loaded products ──
          if (visibleCategories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                spacing: 10,
                children: [
                  _CategoryChip(
                    label: l10n.allCategories,
                    selected: _selectedCategoryId == null,
                    onTap: () => _selectCategory(null),
                  ),
                  ...visibleCategories.map(
                        (cat) => _CategoryChip(
                          label: cat.displayName,
                          selected: _selectedCategoryId == cat.id,
                          onTap: () => _selectCategory(cat.id),
                        ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ── Product grid ──────────────────────────────────────────────────
          Expanded(
            child: !_initialLoadDone
                ? const _GridSkeleton()
                : displayed.isEmpty && !_isLoading
                ? Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? l10n.noResultsFound
                    : l10n.noProductsInSection,
                style: theme.textTheme.bodyMedium,
              ),
            )
                : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification &&
                    n.metrics.pixels >=
                        n.metrics.maxScrollExtent - 40 &&
                    _hasMore) {
                  _load();
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                child: DirectProductsGrid(
                  products: displayed,
                  isLoadingMore: _isLoading && displayed.isNotEmpty,
                  hasMore: _hasMore,
                  onProductTap: (product) => context.push(
                    '/products/${product.id}',
                    extra: product,
                  ),
                  onLoadMore: _load,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sort chip ─────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? Colors.white : Colors.black,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _GridSkeleton extends StatefulWidget {
  const _GridSkeleton();

  @override
  State<_GridSkeleton> createState() => _GridSkeletonState();
}

class _GridSkeletonState extends State<_GridSkeleton>
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
    final crossAxisCount = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: crossAxisCount == 3 ? 400 : 300,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Opacity(
            opacity: _anim.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}