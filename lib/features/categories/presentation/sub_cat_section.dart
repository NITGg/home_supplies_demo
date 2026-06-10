import 'package:flutter/material.dart';

import '../../../core/widgets/image_with_fallback.dart';
import '../../products/data/models/product_model.dart';
import '../../products/presentation/product_card.dart';
import '../../suppliers/data/models/supplier_models.dart';
import '../manager/category_detail_states.dart';

class SubCategorySectionWidget extends StatelessWidget {
  final SubCategorySection section;
  final void Function(ProductModel product) onProductTap;
  final VoidCallback? onLoadMore;
  final Map<int, SupplierModel> suppliersById;

  const SubCategorySectionWidget({
    super.key,
    required this.section,
    required this.onProductTap,
    required this.suppliersById,
    this.onLoadMore,
  });

  /// Groups products by supplierId preserving first-seen order.
  Map<int?, List<ProductModel>> _groupBySupplier(List<ProductModel> products) {
    final groups = <int?, List<ProductModel>>{};
    for (final p in products) {
      (groups[p.supplierId] ??= []).add(p);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (section.products.isEmpty && !section.isLoading) {
      return const SizedBox.shrink();
    }

    final groups = _groupBySupplier(section.products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sub-category header ──────────────────────────────────────────
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

        // ── Products skeleton while initially loading ─────────────────────
        if (section.isLoading && section.products.isEmpty)
          const _ProductListSkeleton()
        else
          // ── One horizontal row per supplier ────────────────────────────
          for (final entry in groups.entries)
            _SupplierProductRow(
              supplier: suppliersById[entry.key],
              products: entry.value,
              isOpen: suppliersById[entry.key]?.currentStatus?.isOpen,
              // Only the last group carries the "load more" spinner so we
              // don't show duplicates.
              isLoadingMore: entry.key == groups.keys.last && section.isLoading,
              hasMore: entry.key == groups.keys.last && section.hasMore,
              onProductTap: onProductTap,
              onLoadMore: onLoadMore,
            ),
      ],
    );
  }
}

// ── Supplier header + horizontal product row ──────────────────────────────────

class _SupplierProductRow extends StatefulWidget {
  final SupplierModel? supplier;
  final List<ProductModel> products;
  final bool isLoadingMore;
  final bool hasMore;
  final bool? isOpen;
  final void Function(ProductModel) onProductTap;
  final VoidCallback? onLoadMore;

  const _SupplierProductRow({
    required this.supplier,
    required this.products,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isOpen,
    required this.onProductTap,
    this.onLoadMore,
  });

  @override
  State<_SupplierProductRow> createState() => _SupplierProductRowState();
}

class _SupplierProductRowState extends State<_SupplierProductRow> {
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
    final supplier = widget.supplier;
    final isOpen = widget.isOpen;
    final itemCount = widget.products.length + (widget.hasMore ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supplier != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _SupplierRowHeader(supplier: supplier, isOpen: isOpen),
          ),

        // ── Products horizontal scroll ────────────────────────────────────
        SizedBox(
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
                    isSupplierOpen: isOpen ?? true,
                    onTap: () => widget.onProductTap(product),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
          child: SizedBox(width: 180, child: _SkeletonCard()),
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

class DirectProductsGrid extends StatelessWidget {
  final List<ProductModel> products;
  final Map<int, SupplierModel> suppliersById;
  final bool isLoadingMore;
  final bool hasMore;
  final void Function(ProductModel) onProductTap;
  final VoidCallback? onLoadMore;

  const DirectProductsGrid({
    super.key,
    required this.products,
    this.suppliersById = const {},
    required this.isLoadingMore,
    required this.hasMore,
    required this.onProductTap,
    this.onLoadMore,
  });

  Map<int?, List<ProductModel>> _groupBySupplier() {
    final groups = <int?, List<ProductModel>>{};
    for (final p in products) {
      (groups[p.supplierId] ??= []).add(p);
    }
    return groups;
  }

  Widget _buildGroup(
    BuildContext context, {
    required int? supplierId,
    required List<ProductModel> groupProducts,
    required bool isLastGroup,
    required int crossAxisCount,
  }) {
    final supplier = suppliersById[supplierId];
    final isOpen = supplier?.currentStatus?.isOpen;

    // When grouped by supplier, render each supplier's products as a
    // horizontal scroll row (there can be many suppliers, so a full grid
    // per supplier would make the page extremely tall).
    if (supplier != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SupplierRowHeader(supplier: supplier, isOpen: isOpen),
          ),
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount:
                  groupProducts.length + (isLastGroup && isLoadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= groupProducts.length) {
                  return const SizedBox(
                    width: 180,
                    child: Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final product = groupProducts[i];
                return SizedBox(
                  width: 180,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ProductCard(
                      product: product,
                      isSupplierOpen: isOpen ?? true,
                      onTap: () => onProductTap(product),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!isLastGroup)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: crossAxisCount == 3 ? 400 : 300,
        ),
        itemCount:
            groupProducts.length + (isLastGroup && isLoadingMore ? 2 : 0),
        itemBuilder: (_, i) {
          if (i >= groupProducts.length) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }
          final product = groupProducts[i];
          return ProductCard(
            product: product,
            isSupplierOpen: isOpen ?? true,
            onTap: () => onProductTap(product),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;

    // Only group by supplier when we actually have supplier data to display.
    // Without it, products from different suppliers would still be split into
    // separate grids (one per unique supplierId) causing lone products to
    // appear visually separated from the rest.
    if (suppliersById.isEmpty) {
      return _buildGroup(
        context,
        supplierId: null,
        groupProducts: products,
        isLastGroup: true,
        crossAxisCount: crossAxisCount,
      );
    }

    final groups = _groupBySupplier();
    final supplierIds = groups.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int g = 0; g < supplierIds.length; g++)
          _buildGroup(
            context,
            supplierId: supplierIds[g],
            groupProducts: groups[supplierIds[g]]!,
            isLastGroup: g == supplierIds.length - 1,
            crossAxisCount: crossAxisCount,
          ),
      ],
    );
  }
}

// ── Shared supplier row header ────────────────────────────────────────────────

class _SupplierRowHeader extends StatelessWidget {
  final SupplierModel supplier;
  final bool? isOpen;

  const _SupplierRowHeader({required this.supplier, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: ClipOval(
            child: supplier.user.personalPhoto != null
                ? ImageWithIconFallback(
                    imageUrl: supplier.user.personalPhoto!,
                    fit: BoxFit.cover,
                  )
                : CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      supplier.user.fullName.isNotEmpty
                          ? supplier.user.fullName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            supplier.user.fullName,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (isOpen != null) _OpenChip(isOpen: isOpen!, locale: locale),
      ],
    );
  }
}

class _OpenChip extends StatelessWidget {
  final bool isOpen;
  final String locale;

  const _OpenChip({required this.isOpen, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Text(
        isOpen
            ? (locale == 'ar' ? 'مفتوح' : 'Open')
            : (locale == 'ar' ? 'مغلق' : 'Closed'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}