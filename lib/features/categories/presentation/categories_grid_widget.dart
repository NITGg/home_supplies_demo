import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/features/ads/ad_manager/ad_cubit.dart';
import 'package:tawreedat_go/features/products/presentation/best_selling_section.dart';
import 'package:tawreedat_go/features/products/presentation/offered_section.dart';

import '../../../l10n/app_localizations.dart';
import '../../addresses/presentation/default_address_chip.dart';
import '../../ads/presentation/widgets/home_ads_carousel.dart';
import '../../ads/presentation/widgets/square_ads_feed.dart';
import '../../cart/manager/cart_cubit.dart';
import '../../cart/manager/cart_state.dart';
import '../../cart/presentation/widgets/cart_button.dart';
import '../../cart/presentation/widgets/cart_icon.dart';
import '../../home/layout/manager/guest_cubit.dart';
import '../../products/presentation/featured_section.dart';
import '../../products/presentation/last_purchase_section.dart';
import '../../search/presentation/search_dialog.dart';
import '../../suppliers/presentation/suppliers_strip_widget.dart';
import '../data/models/category_models.dart';
import '../manager/category_cubit.dart';
import '../manager/category_states.dart';
import 'categories_fallback.dart';
import 'category_card.dart';

/// A self-contained, embeddable categories section.
class CategoriesGridWidget extends StatefulWidget {
  final void Function(CategoryModel category) onCategoryTap;
  final int pageSize;
  final bool showHeader;
  final void Function(bool isEmpty)? onEmptyChanged;

  const CategoriesGridWidget({
    super.key,
    required this.onCategoryTap,
    this.pageSize = 30,
    this.showHeader = true,
    this.onEmptyChanged,
  });

  @override
  State<CategoriesGridWidget> createState() => CategoriesGridWidgetState();
}

class CategoriesGridWidgetState extends State<CategoriesGridWidget> {
  late final CategoriesCubit _cubit;

  /// Incremented on every pull-to-refresh. Passed as a [ValueKey] to each
  /// product section so they are fully recreated (new initState → new _load).
  int _refreshKey = 0;

  Future<void> refresh() async {
    setState(() => _refreshKey++);
    _cubit.loadCategories(refresh: true);
    context.read<AdsCubit>().getHomeAds();
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ads carousel — renders immediately ──────────────────────────
          const HomeAdsCarousel(),

          // ── Product sections — start fetching right away, in parallel
          //    with the categories API call. Each section independently
          //    shows its own skeleton until its own data arrives.
          //    Re-keyed on refresh so they fully recreate and reload.
          OfferedSection(key: ValueKey('offered_$_refreshKey')),
          BestSellingSection(
            key: ValueKey('best_$_refreshKey'),
            loadDelay: const Duration(milliseconds: 200),
          ),
          FeaturedProductsSection(
            key: ValueKey('featured_$_refreshKey'),
            loadDelay: const Duration(milliseconds: 400),
          ),
          BlocBuilder<GuestModeCubit, bool>(
            builder: (context, isGuest) => LastPurchasedSection(
              key: ValueKey('last_purchased_${_refreshKey}_$isGuest'),
              isGuest: isGuest,
              loadDelay: const Duration(milliseconds: 600),
            ),
          ),

          // ── Categories grid — has its own skeleton; independent of above ─
          BlocBuilder<CategoriesCubit, CategoriesState>(
            builder: (context, state) {
              return switch (state) {
                CategoriesInitial() ||
                CategoriesLoading() =>
                const _CategoriesSkeletonRow(),
                CategoriesError() => Center(
                  child: CategoriesFallbackWidget(
                    title: AppLocalizations.of(context)!.welcome,
                    subtitle: AppLocalizations.of(context)!
                        .tawreedatIsYourBestChoice,
                    lottieAsset:
                    'assets/animation_json/Shopping_cart_animation.json',
                  ),
                ),
                CategoriesLoaded() => Builder(builder: (context) {
                  final isEmpty = state.categories
                      .where((c) => c.parentId == null)
                      .isEmpty;

                  // Notify parent after the frame settles
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onEmptyChanged?.call(isEmpty);
                  });

                  if (isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        child: SquareAdsFeed(),
                      ),
                    );
                  }

                  final isGuest = context.read<GuestModeCubit>().state;

                  return _CategoriesGrid(
                    state: state,
                    onCategoryTap: widget.onCategoryTap,
                    showHeader: widget.showHeader,
                    isGuest: isGuest,
                  );
                }),
              };
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Categories grid — label + card grid + suppliers strip only.
// Product sections have been moved up into CategoriesGridWidget so they
// load in parallel with (not after) the categories API call.
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesGrid extends StatelessWidget {
  final CategoriesLoaded state;
  final void Function(CategoryModel) onCategoryTap;
  final bool showHeader;
  final bool isGuest;

  static const int _homeGridLimit = 6;

  const _CategoriesGrid({
    required this.state,
    required this.onCategoryTap,
    this.showHeader = true,
    this.isGuest = false,
  });

  List<CategoryModel> get _parents =>
      state.categories.where((c) => c.parentId == null).toList();

  List<CategoryModel> get _visibleParents =>
      _parents.take(_homeGridLimit).toList();

  bool get _hasMore => _parents.length > _homeGridLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Optional sticky header ───────────────────────────────────────
        if (showHeader)
          Material(
            elevation: 0,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
              child: Row(
                children: [
                  if (!isGuest) ...[
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.kPrimaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const DefaultAddressChip(),
                    const SizedBox(width: 8),
                    const Spacer(),
                  ],
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    child: IconButton(
                      icon: Icon(Icons.search_rounded,
                          color: Colors.grey.shade700),
                      onPressed: () => showSearchDialog(context),
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
                  CartButton(),
                ],
              ),
            ),
          ),

        // ── "Categories" label + View All ───────────────────────────────
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
                AppLocalizations.of(context)!.categories,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_hasMore)
                GestureDetector(
                  onTap: () => context.push('/categories'),
                  child: Text(
                    AppLocalizations.of(context)!.viewAll,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.kPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Grid (capped at 6) ───────────────────────────────────────────
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.82,
          ),
          itemCount: _visibleParents.length,
          itemBuilder: (_, i) => CategoryCard(
            category: _visibleParents[i],
            onTap: () => onCategoryTap(_visibleParents[i]),
            style: CategoryCardStyle.regular,
          ),
        ),

        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade200, height: 1),

        // ── Suppliers Strip ──────────────────────────────────────────────
        const SuppliersStripWidget(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton shown only while the categories cubit is loading
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fake "Categories" label
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
        // Fake 3×2 grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: 6,
            itemBuilder: (_, __) => AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Opacity(
                opacity: _anim.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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