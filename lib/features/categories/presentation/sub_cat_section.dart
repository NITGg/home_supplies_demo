import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cart/manager/cart_cubit.dart';
import '../../products/data/models/product_model.dart';
import '../../products/presentation/product_card.dart';
import '../manager/category_detail_states.dart';

/// Widget that renders a single sub-category header + its products grid.
/// Named [SubCategorySectionWidget] to avoid collision with the
/// [SubCategorySection] data class defined in category_detail_state.dart.
class SubCategorySectionWidget extends StatelessWidget {
  final SubCategorySection section;
  final void Function(ProductModel product) onProductTap;
  final VoidCallback? onLoadMore;

  const SubCategorySectionWidget({
    super.key,
    required this.section,
    required this.onProductTap,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ─────────────────────────────────────────────────
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

        // ── Products grid or skeleton ──────────────────────────────────────
        if (section.isLoading && section.products.isEmpty)
          _ProductGridSkeleton()
        else if (section.products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'لا توجد منتجات في هذه الفئة',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _ProductGrid(
              products: section.products,
              onProductTap: onProductTap,
            ),
          ),

        // ── Load more ─────────────────────────────────────────────────────
        if (section.hasMore && section.products.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: section.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: onLoadMore,
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: const Text('عرض المزيد'),
                    ),
            ),
          ),
      ],
    );
  }
}

// ── Product grid ──────────────────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  final List<ProductModel> products;
  final void Function(ProductModel) onProductTap;

  const _ProductGrid({required this.products, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _crossAxisCount(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) {
            final product = products[i];
            return ProductCard(
              product: product,
              onTap: () => onProductTap(product),
              onQuantityChanged: (qty) {
                if (qty == 1) {
                  // first add only
                  context.read<CartCubit>().addItem(
                    spId: product.spId ?? product.id,
                    quantity: 1,
                  );
                }
                // subsequent taps are local UI only until user goes to cart
              },
            );
          },
        );
      },
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 900) return 5;
    if (width >= 700) return 4;
    if (width >= 500) return 3;
    return 2;
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _ProductGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => const _SkeletonCard(),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ProductGrid(products: products, onProductTap: onProductTap),
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: isLoadingMore
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: onLoadMore,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('تحميل المزيد'),
                  ),
          ),
      ],
    );
  }
}
