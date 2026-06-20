import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/features/products/presentation/product_card.dart';
import 'package:tawreedat_go/features/products/presentation/product_secttion_skeleton.dart';

import '../../../core/utils/logger.dart';
import '../../../core/utils/secure_storage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/data/models/product_model.dart';
import '../../products/data/repo/product_repo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProductHorizontalSection
//
// A single generic widget that replaces BestSellingSection, FeaturedSection,
// OfferedSection, and LastPurchasedSection.
//
// Key differences vs the old per-section widgets
// ───────────────────────────────────────────────
// • One shared [ProductRepository] can be injected from outside (avoids
//   creating 4 independent repo instances).
// • Guest-awareness is handled inside [didUpdateWidget]: when [isGuest] flips
//   from true→false the section reloads without being destroyed and recreated.
// • [requiresAuth] replaces the per-class guard logic: when true the section
//   skips its load when [isGuest] is true and never shows a skeleton to guests.
// • No artificial load delays — staggered loading is the caller's concern.
//
// Usage (in CategoriesGridWidget)
// ────────────────────────────────
//   ProductHorizontalSection(
//     key: ValueKey('offered_$_refreshKey'),
//     label: (l10n) => l10n.offers,
//     viewAllRoute: '/offered',
//     repo: _repo,
//     queryParam: ProductQueryParam.offered,
//   )
//
//   ProductHorizontalSection(
//     key: ValueKey('last_$_refreshKey'),
//     label: (l10n) => l10n.purchasedBefore,
//     viewAllRoute: '/last-purchased',
//     repo: _repo,
//     queryParam: ProductQueryParam.lastPurchased,
//     requiresAuth: true,
//     isGuest: isGuest,
//   )
// ─────────────────────────────────────────────────────────────────────────────

/// Which filter flag to pass to [ProductRepository.getProducts].
enum ProductQueryParam {
  offered,
  bestSelling,
  featured,
  lastPurchased,
}

class ProductHorizontalSection extends StatefulWidget {
  /// Localized section label — receives [AppLocalizations] and returns the string.
  final String Function(AppLocalizations l10n) label;

  /// The go_router route to push when the user taps "View All".
  final String viewAllRoute;

  /// Shared repository instance — avoids creating a new impl per section.
  final ProductRepository repo;

  /// Which API filter to apply.
  final ProductQueryParam queryParam;

  /// When [true] the section is invisible to guests; skips the load and
  /// shows nothing (not even a skeleton) until the user logs in.
  final bool requiresAuth;

  /// Current guest state. Ignored when [requiresAuth] is false.
  final bool isGuest;

  const ProductHorizontalSection({
    super.key,
    required this.label,
    required this.viewAllRoute,
    required this.repo,
    required this.queryParam,
    this.requiresAuth = false,
    this.isGuest = false,
  });

  @override
  State<ProductHorizontalSection> createState() =>
      _ProductHorizontalSectionState();
}

class _ProductHorizontalSectionState extends State<ProductHorizontalSection> {
  static const int _pageSize = 5;

  final ScrollController _scrollController = ScrollController();

  List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  bool _initialLoadDone = false;
  bool _scrollDebounce = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!widget.requiresAuth || !widget.isGuest) {
      _load();
    }
  }

  /// Handles the guest→logged-in transition without requiring the widget to be
  /// destroyed. When [isGuest] flips to false we reset state and reload.
  @override
  void didUpdateWidget(ProductHorizontalSection old) {
    super.didUpdateWidget(old);
    if (widget.requiresAuth && old.isGuest && !widget.isGuest) {
      // User just logged in — reset and fetch.
      if (!mounted) return;
      setState(() {
        _products = [];
        _skip = 0;
        _hasMore = true;
        _initialLoadDone = false;
      });
      _load();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollDebounce) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      _scrollDebounce = true;
      _load().whenComplete(() {
        if (mounted) setState(() => _scrollDebounce = false);
      });
    }
  }

  Future<void> _load() async {
    if (_isLoading || !_hasMore || !mounted) return;
    if (widget.requiresAuth) {
      if (widget.isGuest) return;
      // Extra guard: check token in case guest flag lags behind storage.
      final token = await SecureStorageService().getToken();
      if (token == null || token.isEmpty) return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await widget.repo.getProducts(
        skip: _skip,
        limit: _pageSize,
        // Use true-or-null — never false. The data source omits null
        // params entirely; passing false would filter *out* products
        // that also carry other flags (e.g. is_featured=true).
        isOffered:       widget.queryParam == ProductQueryParam.offered       ? true : null,
        isBestSelling:   widget.queryParam == ProductQueryParam.bestSelling   ? true : null,
        isFeatured:      widget.queryParam == ProductQueryParam.featured      ? true : null,
        isLastPurchased: widget.queryParam == ProductQueryParam.lastPurchased ? true : null,
      );

      if (!mounted) return;

      setState(() {
        _products = [..._products, ...response.products];
        _skip += response.products.length;
        _hasMore = _skip < response.totalProducts;
        _isLoading = false;
        _initialLoadDone = true;
      });
    } catch (e) {
      dLog('[ProductHorizontalSection(${widget.queryParam.name})] error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initialLoadDone = true;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Guests never see auth-gated sections — skip even the skeleton.
    if (widget.requiresAuth && widget.isGuest) return const SizedBox.shrink();

    // Show skeleton while the first load is in progress.
    if (!_initialLoadDone) return const ProductSectionSkeleton();

    // Nothing to show — collapse entirely.
    if (_products.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Section label + View All ─────────────────────────────────────
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
                widget.label(l10n),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(widget.viewAllRoute),
                child: Text(
                  l10n.viewAll,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal list ───────────────────────────────────────────────
        Builder(builder: (context) {
          final cardWidth = 180.0;

          return SizedBox(
            height: 300,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _products.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _products.length) {
                  return const ProductSectionLoadingCard();
                }
                final product = _products[index];
                return SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ProductCard(
                      product: product,
                      onTap: () =>
                          context.push('/products/${product.id}', extra: product),
                    ),
                  ),
                );
              },
            ),
          );
        }),

        const SizedBox(height: 8),
      ],
    );
  }
}