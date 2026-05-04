
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';

import '../../../core/widgets/circel_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/category_models.dart';
import '../manager/category_cubit.dart';
import '../manager/category_states.dart';
import 'categories_fallback.dart';
import 'category_card.dart';

/// Full-page categories grid — no item limit.
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  late final CategoriesCubit _cubit;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.categories),
        leading: CircleBackButton(),
        elevation: 0,
      ),
      body: BlocProvider.value(
        value: _cubit,
        child: BlocBuilder<CategoriesCubit, CategoriesState>(
          builder: (context, state) {
            return switch (state) {
              CategoriesInitial() || CategoriesLoading() => const _GridSkeleton(),
              CategoriesError() => Center(
                child: CategoriesFallbackWidget(
                  title: AppLocalizations.of(context)!.welcome,
                  subtitle:
                  AppLocalizations.of(context)!.tawreedatIsYourBestChoice,
                  lottieAsset:
                  'assets/animation_json/Shopping_cart_animation.json',
                ),
              ),
              CategoriesLoaded() => _AllCategoriesBody(
                state: state,
                onLoadMore: _cubit.loadMore,
                onCategoryTap: (category) =>
                    context.push('/categories/${category.id}'),
              ),
            };
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _AllCategoriesBody extends StatelessWidget {
  final CategoriesLoaded state;
  final VoidCallback onLoadMore;
  final void Function(CategoryModel category) onCategoryTap;

  const _AllCategoriesBody({
    required this.state,
    required this.onLoadMore,
    required this.onCategoryTap,
  });

  List<CategoryModel> get _parents =>
      state.categories.where((c) => c.parentId == null).toList();

  @override
  Widget build(BuildContext context) {
    if (_parents.isEmpty) {
      return Center(
        child: CategoriesFallbackWidget(
          title: AppLocalizations.of(context)!.welcome,
          subtitle: AppLocalizations.of(context)!.tawreedatIsYourBestChoice,
          lottieAsset: 'assets/animation_json/Shopping_cart_animation.json',
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 40 &&
            state.hasMore) {
          onLoadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => CategoryCard(
                  category: _parents[i],
                  onTap: () => onCategoryTap(_parents[i]),
                  style: CategoryCardStyle.regular,
                ),
                childCount: _parents.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
            ),
          ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Opacity(
            opacity: _anim.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}