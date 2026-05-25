import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/circel_back_button.dart';

import '../../../core/utils/logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/widgets/cart_button.dart';
import '../../categories/presentation/sub_cat_section.dart';
import '../../products/data/models/product_model.dart';
import '../../products/data/repo/product_repo.dart';

/// Full-page grid of all featured products.
class AllFeaturedProductsScreen extends StatefulWidget {
  const AllFeaturedProductsScreen({super.key});

  @override
  State<AllFeaturedProductsScreen> createState() =>
      _AllFeaturedProductsScreenState();
}

class _AllFeaturedProductsScreenState extends State<AllFeaturedProductsScreen> {
  static const int _pageSize = 10;

  final ProductRepository _repo = ProductRepositoryImpl();
  final ScrollController _scrollController = ScrollController();

  List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final response = await _repo.getProducts(
        skip: _skip,
        limit: _pageSize,
        isFeatured: true,
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
      dLog('[AllFeaturedProductsScreen] error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _initialLoadDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.featured,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: CircleBackButton(),
        elevation: 0,
        actions: [CartButton()],
      ),
      body: !_initialLoadDone
          ? const _GridSkeleton()
          : _products.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noProductsInSection,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification &&
                    n.metrics.pixels >= n.metrics.maxScrollExtent - 40 &&
                    _hasMore) {
                  _load();
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                child: DirectProductsGrid(
                  products: _products,
                  isLoadingMore: _isLoading,
                  hasMore: _hasMore,
                  onProductTap: (product) =>
                      context.push('/products/${product.id}', extra: product),
                  onLoadMore: _load,
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

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
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
