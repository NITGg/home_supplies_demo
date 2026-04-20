import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/features/categories/presentation/sub_cat_section.dart';

import '../../../core/widgets/circel_back_cutton.dart';
import '../../../core/widgets/image_with_fallback.dart';
import '../../cart/presentation/cart_icon.dart';
import '../../products/data/models/product_model.dart';
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
          _CategorySliverAppBar(category: state.category),
          if (state.hasSections)
            SliverList.separated(
              itemCount: state.sections.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
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
    final hasImage = category.imageUrl != null && category.imageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: CircleBackButton(),
      actions: [
        // Animated cart icon with bounce-on-add animation.
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

        // Cinematic bottom-heavy scrim
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

        // Title block
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
                        'تصنيف فرعي',
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
                  maxLines: 1,
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
            'لا توجد منتجات في هذا التصنيف',
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
// Matches the loaded view structure exactly:
//  • When a [category] is available (navigation from list), the real
//    _CategorySliverAppBar is rendered so the header snaps in instantly.
//  • When only an ID was supplied, a matching gradient placeholder is shown.
//  • Below the header, a pulsing skeleton product grid fills the content area.

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
    _pulse = Tween<double>(begin: 0.06, end: 0.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
            // ── Header: reuse the real widget when category is known ─────────
            if (widget.category != null)
              _CategorySliverAppBar(category: widget.category!)
            else
              _GradientPlaceholderAppBar(shimmer: shimmer),

            // ── Skeleton product grid ────────────────────────────────────────
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

// ── Gradient placeholder app bar (used when category model is not yet known) ──

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
            // Gradient mesh matching _GradientMesh aesthetic
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
                    HSLColor.fromColor(secondary).withSaturation(0.9).toColor(),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Radial highlight orb
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
            // Cinematic scrim
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
            // Skeleton title block
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
          // Image area
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
          // Info area
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Name line 1
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // Name line 2 (shorter)
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // Price stub
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