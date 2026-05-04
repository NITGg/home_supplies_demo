import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../products/data/models/product_model.dart';
import '../../products/presentation/product_card.dart';
import '../manager/category_detail_states.dart';

class SubCategorySectionWidget extends StatelessWidget {
  final SubCategorySection section;
  final void Function(ProductModel product) onProductTap;
  final VoidCallback? onLoadMore; // restored
  final bool isSupplierOpen;

  const SubCategorySectionWidget({
    super.key,
    required this.section,
    required this.onProductTap,
    this.onLoadMore,
    this.isSupplierOpen = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return section.products.isEmpty? SizedBox.shrink():Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ───────────────────────────────────────────────
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
                  section.subCategory.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Products list or skeleton ────────────────────────────────────
        if (section.isLoading && section.products.isEmpty)
          const _ProductListSkeleton()
        else if (section.products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              AppLocalizations.of(context)!.noProductsInSection,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          )
        else
          _ProductList(
            products: section.products,
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

// ── Horizontal product list ───────────────────────────────────────────────────

class _ProductList extends StatefulWidget {
  final List<ProductModel> products;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isSupplierOpen;
  final void Function(ProductModel) onProductTap;
  final VoidCallback? onLoadMore;

  const _ProductList({
    required this.products,
    required this.isLoadingMore,
    required this.hasMore,
    this.isSupplierOpen = true,
    required this.onProductTap,
    this.onLoadMore,
  });

  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // +1 for the trailing loader slot when loading more
    final itemCount = widget.products.length + (widget.hasMore ? 1 : 0);

    return SizedBox(
      height: 300,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          // Trailing spinner card
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
            width: 160,
            child: Padding(
              padding: const EdgeInsets.only(right: 10,bottom: 20),
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
  const _ProductListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(right: 10),
          child: SizedBox(width: 160, child: _SkeletonCard()),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

// ── Standalone product grid (for direct products / no sub-categories) ─────────

// ── Standalone product grid (for direct products / no sub-categories) ─────────

class DirectProductsGrid extends StatelessWidget {
  final List<ProductModel> products;
  final bool isLoadingMore;
  final bool hasMore;
  final void Function(ProductModel) onProductTap;
  final VoidCallback? onLoadMore;

  const DirectProductsGrid({
    super.key,
    required this.products,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onProductTap,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(), // outer CustomScrollView handles scrolling
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            // childAspectRatio: 0.72,
            mainAxisExtent:crossAxisCount == 3 ? 400: 300
        ),
        itemCount: products.length + (isLoadingMore ? 2 : 0), // 2 skeleton placeholders at end
        itemBuilder: (_, i) {
          if (i >= products.length) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }
          final product = products[i];
          return SizedBox(
            child: ProductCard(
              product: product,
              onTap: () => onProductTap(product),
            ),
          );
        },
      ),
    );
  }
}