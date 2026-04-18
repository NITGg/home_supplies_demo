import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/categories/presentation/sub_cat_section.dart';

import '../../products/data/models/product_model.dart';
import '../data/models/category_models.dart';
import '../manager/category_detail_cubit.dart';
import '../manager/category_detail_states.dart';

class CategoryDetailScreen extends StatefulWidget {
  /// Pass either [category] (from list navigation) or [categoryId] (deep link).
  final CategoryModel? category;
  final int? categoryId;

  const CategoryDetailScreen({
    super.key,
    this.category,
    this.categoryId,
  }) : assert(category != null || categoryId != null);

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
                onLoadMoreSection: (subCatId) =>
                    _cubit.loadMoreSectionProducts(subCatId),
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
    Navigator.of(context).pushNamed(
      '/products/detail',
      arguments: product,
    );
    // Or with GoRouter:
    // context.push('/products/${product.id}', extra: product);
  }
}

// ── Loaded View ───────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          // ── Collapsible app bar with category image ──────────────────────
          _CategorySliverAppBar(category: state.category),

          // ── Category description card ────────────────────────────────────
          if (state.category.displayDescription.isNotEmpty)
            SliverToBoxAdapter(
              child: _CategoryInfoCard(category: state.category),
            ),

          // ── Products: grouped by sub-category OR flat list ───────────────
          if (state.hasSections)
            SliverList.separated(
              itemCount: state.sections.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (_, i) {
                final section = state.sections[i];
                return SubCategorySectionWidget(
                  section: section,
                  onProductTap: onProductTap,
                  onLoadMore: section.hasMore
                      ? () => onLoadMoreSection(section.subCategory.id)
                      : null,
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
                onProductTap: onProductTap,
                onLoadMore: onLoadMoreDirect,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
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

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          category.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
          ),
        ),
        background: category.imageUrl != null
            ? Image.network(
          category.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _headerPlaceholder(theme, category),
        )
            : _headerPlaceholder(theme, category),
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
      ),
    );
  }

  Widget _headerPlaceholder(ThemeData theme, CategoryModel cat) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          cat.displayName.isNotEmpty ? cat.displayName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

// ── Category info card ────────────────────────────────────────────────────────

class _CategoryInfoCard extends StatelessWidget {
  final CategoryModel category;

  const _CategoryInfoCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: Text(
        category.displayDescription,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.6,
        ),
      ),
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
          Icon(Icons.inventory_2_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'لا توجد منتجات في هذا التصنيف',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final CategoryModel? category;

  const _LoadingView({this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: category != null ? Text(category!.displayName) : null,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
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
                  Icon(Icons.error_outline,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
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