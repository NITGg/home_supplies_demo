import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

import '../../../l10n/app_localizations.dart';
import '../../addresses/presentation/default_address_chip.dart';
import '../../cart/manager/cart_cubit.dart';
import '../../cart/manager/cart_state.dart';
import '../../cart/presentation/cart_icon.dart';
import '../data/models/category_models.dart';
import '../manager/category_cubit.dart';
import '../manager/category_states.dart';
import 'categories_fallback.dart';
import 'category_card.dart';

/// A self-contained, embeddable categories section.
///
/// Owns its own [CategoriesCubit] — just drop it anywhere and it loads itself.
/// Never scrolls independently: compact style uses a [SingleChildScrollView]
/// row, regular style uses a [GridView] with [shrinkWrap] so the parent
/// scroll view stays in control.
class CategoriesGridWidget extends StatefulWidget {
  final void Function(CategoryModel category) onCategoryTap;

  /// How many items to request per page.
  final int pageSize;

  const CategoriesGridWidget({
    super.key,
    required this.onCategoryTap,
    this.pageSize = 30,
  });

  @override
  State<CategoriesGridWidget> createState() => CategoriesGridWidgetState();
}

class CategoriesGridWidgetState extends State<CategoriesGridWidget> {
  late final CategoriesCubit _cubit;

  Future<void> refresh() => _cubit.loadCategories(refresh: true);

  @override
  void initState() {
    super.initState();
    _cubit = CategoriesCubit();
    _cubit.loadCategories();
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
      child: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          return switch (state) {
            CategoriesInitial() ||
            CategoriesLoading() => const _CategoriesSkeletonRow(),
            CategoriesError() => Center(
              child: CategoriesFallbackWidget(
                title: AppLocalizations.of(context)!.welcome,
                subtitle: AppLocalizations.of(context)!.tawreedatIsYourBestChoice,
                lottieAsset: 'assets/animation_json/Shopping_cart_animation.json',
              ),
            ),
            CategoriesLoaded() => _CategoriesSection(
              state: state,
              onCategoryTap: widget.onCategoryTap,
              onLoadMore: _cubit.loadMore,
            ),
          };
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section wrapper (title + adaptive grid)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesSection extends StatelessWidget {
  final CategoriesLoaded state;
  final void Function(CategoryModel) onCategoryTap;
  final VoidCallback onLoadMore;

  const _CategoriesSection({
    required this.state,
    required this.onCategoryTap,
    required this.onLoadMore,
  });

  List<CategoryModel> get _parents =>
      state.categories.where((c) => c.parentId == null).toList();

  bool get _useCompact => false;

  int get _crossAxisCount {
    if (!_useCompact) return 3;
    if (_parents.length > 12) return 5;
    return 4;
  }

  double get _childAspectRatio => _useCompact ? 0.95 : 0.82;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return state.totalCount == 0
        ? Center(
      child: CategoriesFallbackWidget(
        title: AppLocalizations.of(context)!.welcome,
        subtitle: AppLocalizations.of(context)!.tawreedatIsYourBestChoice,
        lottieAsset: 'assets/animation_json/Shopping_cart_animation.json',
      ),
    )
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
          child: Row(
            children: [
              // Title accent bar
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.categories,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),

              // ── Default address chip ──────────────────────────────
              const DefaultAddressChip(),
              const SizedBox(width: 8),

              // ── Search button ─────────────────────────────────────
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade700,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                ),
              ),

              if (state.isLoadingMore)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),

              // ── Cart icon ─────────────────────────────────────────
              BlocSelector<CartCubit, CartState, int>(
                selector: (state) {
                  if (state is CartLoaded) {
                    final total = state.data.summary.totalItems;
                    return total < 0 ? 0 : total;
                  }
                  return 0;
                },
                builder: (context, count) {
                  return AnimatedCartIcon(
                    onTap: () => context.push('/cart'),
                  );
                },
              ),
            ],
          ),
        ),

        // ── Always a grid ─────────────────────────────────────────────
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 40 &&
                state.hasMore) {
              onLoadMore();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: _childAspectRatio,
            ),
            itemCount: _parents.length,
            itemBuilder: (_, i) => CategoryCard(
              category: _parents[i],
              onTap: () => onCategoryTap(_parents[i]),
              style: _useCompact
                  ? CategoryCardStyle.compact
                  : CategoryCardStyle.regular,
            ),
          ),
        ),

        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton row (shown while loading)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesSkeletonRow extends StatefulWidget {
  const _CategoriesSkeletonRow();

  @override
  State<_CategoriesSkeletonRow> createState() => _CategoriesSkeletonRowState();
}

class _CategoriesSkeletonRowState extends State<_CategoriesSkeletonRow>
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Skeleton header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Opacity(
              opacity: _anim.value,
              child: Container(
                width: 90,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),

        // ── Skeleton grid ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemCount: 8,
            itemBuilder: (_, __) => AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Opacity(
                opacity: _anim.value,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
      ],
    );
  }
}