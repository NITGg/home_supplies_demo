// search_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/image_with_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/widgets/cart_button.dart';
import '../../products/data/models/product_model.dart';
import '../../products/presentation/product_card.dart';
import '../../suppliers/data/models/supplier_models.dart';
import '../data/data_source/search_remote_data_source.dart';
import '../data/repo/search_repo.dart';
import '../manager/search_cubit.dart';
import '../manager/search_states.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point – replaces showSearchDialog
// ─────────────────────────────────────────────────────────────────────────────

void showSearchDialog(BuildContext context) => context.push('/search');

// ─────────────────────────────────────────────────────────────────────────────
// Screen widget (registered in the router as /search)
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchCubit(
        SearchRepositoryImpl(SearchRemoteDataSource()),
      ),
      child: const _SearchScreenBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _SearchScreenBody extends StatefulWidget {
  const _SearchScreenBody();

  @override
  State<_SearchScreenBody> createState() => _SearchScreenBodyState();
}

class _SearchScreenBodyState extends State<_SearchScreenBody> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SearchCubit>();
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      // ── App bar with search field ─────────────────────────────────────────
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: loc.search,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: cubit.onQueryChanged,
          onSubmitted: (_) {},
        ),
        actions: [
          // Clear button — visible only while there is text
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      cubit.reset();
                      _focusNode.requestFocus();
                    },
                  ),
          ),
          const CartButton(),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor),
        ),
      ),

      // ── Body ──────────────────────────────────────────────────────────────
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: switch (state) {
              SearchInitial() => _HintView(key: const ValueKey('hint')),
              SearchLoading() => _LoadingView(key: const ValueKey('loading')),
              SearchEmpty() => _EmptyView(key: const ValueKey('empty')),
              SearchError(:final message) =>
                _ErrorView(key: const ValueKey('error'), message: message),
              SearchSuccess() => _SuccessView(
                  key: const ValueKey('results'),
                  state: state,
                  onProductTap: (p) => context.push('/products/${p.id}', extra: p),
                  onCategorySelected: cubit.selectCategory,
                ),
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success view: category chips + products grouped by supplier
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final SearchSuccess state;
  final void Function(ProductModel) onProductTap;
  final void Function(int?) onCategorySelected;

  const _SuccessView({
    super.key,
    required this.state,
    required this.onProductTap,
    required this.onCategorySelected,
  });

  /// Groups [products] by supplierId preserving first-seen order.
  /// null supplierId = all products without supplier info land in one group.
  Map<int?, List<ProductModel>> _groupBySupplier(List<ProductModel> products) {
    final groups = <int?, List<ProductModel>>{};
    for (final p in products) {
      (groups[p.supplierId] ??= []).add(p);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final products = state.filteredProducts;
    final categories = state.result.categories;
    final suppliersById = state.result.suppliersById;
    final groups = _groupBySupplier(products);

    return CustomScrollView(
      slivers: [
        // ── Category filter chips ─────────────────────────────────────────
        if (categories.isNotEmpty)
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryChipsDelegate(
              categories: categories,
              selectedId: state.selectedCategoryId,
              onSelected: onCategorySelected,
            ),
          ),

        // ── No products after filtering ───────────────────────────────────
        if (products.isEmpty)
          const SliverFillRemaining(child: _EmptyView()),

        // ── Supplier groups ───────────────────────────────────────────────
        for (final entry in groups.entries)
          SliverToBoxAdapter(
            child: _SupplierGroup(
              supplier: suppliersById[entry.key],
              products: entry.value,
              onProductTap: onProductTap,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky category chips header
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChipsDelegate extends SliverPersistentHeaderDelegate {
  final List<dynamic> categories; // List<CategoryModel>
  final int? selectedId;
  final void Function(int?) onSelected;

  static const double _height = 52.0;

  const _CategoryChipsDelegate({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_CategoryChipsDelegate old) =>
      old.selectedId != selectedId || old.categories.length != categories.length;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final elevated = overlapsContent || shrinkOffset > 0;

    return Material(
      color: theme.colorScheme.surface,
      elevation: elevated ? 2 : 0,
      shadowColor: Colors.black.withOpacity(0.10),
      child: SizedBox(
        height: _height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: categories.length + 1, // +1 for "All" chip
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            // First chip is always "All"
            if (i == 0) {
              return _FilterChip(
                label: locale == 'ar' ? 'الكل' : 'All',
                isActive: selectedId == null,
                theme: theme,
                onTap: () => onSelected(null),
              );
            }
            final cat = categories[i - 1];
            final id = cat.id as int;
            final name = cat.displayName as String? ?? '';
            return _FilterChip(
              label: name,
              isActive: selectedId == id,
              theme: theme,
              onTap: () => onSelected(selectedId == id ? null : id),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final ThemeData theme;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withOpacity(0.35),
                width: 0.8,
              ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: theme.textTheme.labelMedium!.copyWith(
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One supplier group: header (if known) + horizontal product row
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierGroup extends StatelessWidget {
  final SupplierModel? supplier;
  final List<ProductModel> products;
  final void Function(ProductModel) onProductTap;

  const _SupplierGroup({
    required this.supplier,
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isOpen = supplier?.currentStatus?.isOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Supplier header ─────────────────────────────────────────────────
        if (supplier != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                // Avatar
                SizedBox(
                  width: 32,
                  height: 32,
                  child: ClipOval(
                    child: supplier!.user.personalPhoto != null
                        ? ImageWithIconFallback(
                            imageUrl: supplier!.user.personalPhoto!,
                            fit: BoxFit.cover,
                          )
                        : CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            child: Text(
                              supplier!.user.fullName.isNotEmpty
                                  ? supplier!.user.fullName[0].toUpperCase()
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
                    supplier!.user.fullName,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOpen != null) ...[
                  const SizedBox(width: 8),
                  _OpenChip(isOpen: isOpen, locale: locale),
                ],
              ],
            ),
          )
        else
          const SizedBox(height: 12),

        // ── Product horizontal scroll ───────────────────────────────────────
        SizedBox(
          height: 290,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (_, i) => SizedBox(
              width: 180,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 12),
                child: ProductCard(
                  product: products[i],
                  isSupplierOpen: isOpen ?? true,
                  onTap: () => onProductTap(products[i]),
                ),
              ),
            ),
          ),
        ),

        Divider(color: Colors.grey.shade100, height: 1),
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

// ─────────────────────────────────────────────────────────────────────────────
// State views
// ─────────────────────────────────────────────────────────────────────────────

class _HintView extends StatelessWidget {
  const _HintView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.typeToSearchProducts,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noResultsFound,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: TextStyle(color: Colors.red.shade400, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
