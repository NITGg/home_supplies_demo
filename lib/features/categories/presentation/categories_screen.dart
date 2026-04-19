import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/category_models.dart';
import '../manager/category_cubit.dart';
import '../manager/category_states.dart';
import 'category_card.dart';


class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoriesCubit _cubit;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cubit = CategoriesCubit();
    _cubit.loadCategories();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _cubit.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cubit.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التصنيفات'),
          centerTitle: true,
        ),
        body: BlocBuilder<CategoriesCubit, CategoriesState>(
          builder: (context, state) {
            return switch (state) {
              CategoriesInitial() => const SizedBox.shrink(),
              CategoriesLoading() => const _CategoriesLoadingView(),
              CategoriesError(:final message) => _ErrorView(
                message: message,
                onRetry: () => _cubit.loadCategories(),
              ),
              CategoriesLoaded() => _CategoriesLoadedView(
                state: state,
                scrollController: _scrollController,
                onCategoryTap: _navigateToCategory,
              ),
            };
          },
        ),
      ),
    );
  }

  void _navigateToCategory(CategoryModel category) {
    Navigator.of(context).pushNamed(
      '/categories/detail',
      arguments: category,
    );
    // Or with GoRouter:
    // context.push('/categories/${category.id}', extra: category);
  }
}

// ── Loaded view ───────────────────────────────────────────────────────────────

class _CategoriesLoadedView extends StatelessWidget {
  final CategoriesLoaded state;
  final ScrollController scrollController;
  final void Function(CategoryModel) onCategoryTap;

  // Threshold: more than this count → compact style
  static const int _compactThreshold = 2;

  const _CategoriesLoadedView({
    required this.state,
    required this.scrollController,
    required this.onCategoryTap,
  });

  bool get _useCompact => state.totalCount > _compactThreshold;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () =>
          context.read<CategoriesCubit>().loadCategories(refresh: true),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _useCompact
                ? _CompactCategoryGrid(
              categories: state.categories,
              onTap: onCategoryTap,
            )
                : _RegularCategoryGrid(
              categories: state.categories,
              onTap: onCategoryTap,
            ),
          ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Regular grid (few categories — large cards) ───────────────────────────────

class _RegularCategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final void Function(CategoryModel) onTap;

  const _RegularCategoryGrid({
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.crossAxisExtent >= 700 ? 3 : 2;
        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (_, i) => CategoryCard(
              category: categories[i],
              onTap: () => onTap(categories[i]),
              style: CategoryCardStyle.regular,
            ),
            childCount: categories.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
        );
      },
    );
  }
}

// ── Compact grid (many categories — small rounded chips) ─────────────────────

class _CompactCategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final void Function(CategoryModel) onTap;

  const _CompactCategoryGrid({
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _crossAxisCount(constraints.crossAxisExtent);
        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (_, i) => CategoryCard(
              category: categories[i],
              onTap: () => onTap(categories[i]),
              style: CategoryCardStyle.compact,
            ),
            childCount: categories.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
        );
      },
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 700) return 8;
    if (width >= 500) return 6;
    return 4;
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _CategoriesLoadingView extends StatelessWidget {
  const _CategoriesLoadingView();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
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
    _anim = Tween<double>(begin: 0.3, end: 0.9).animate(
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
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}