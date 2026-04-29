import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../ads/presentation/widgets/popups.dart';
import '../../addresses/presentation/default_address_chip.dart';
import '../../cart/manager/cart_cubit.dart';
import '../../cart/manager/cart_state.dart';
import '../../cart/presentation/widgets/cart_icon.dart';
import '../../search/presentation/search_dialog.dart';
import '../data/models/category_models.dart';
import 'categories_grid_widget.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final GlobalKey<CategoriesGridWidgetState> _categoriesKey = GlobalKey();

  void _navigateToCategory(CategoryModel category) {
    context.push('/categories/${category.id}', extra: category);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () =>
        _categoriesKey.currentState?.refresh() ?? Future.value(),
        color: AppColors.kPrimaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: PopupAdsHandler()),

            // Pinned sticky header — only the search/address/cart row
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(),
            ),

            // Everything else scrolls: ads + featured + grid
            SliverToBoxAdapter(
              child: CategoriesGridWidget(
                key: _categoriesKey,
                onCategoryTap: _navigateToCategory,
                showHeader: false,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 300)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky search bar delegate
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            // Accent bar
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.kPrimaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),

            // Default address chip
            const DefaultAddressChip(),
            const SizedBox(width: 8),
            const Spacer(),

            // Search button
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: Icon(Icons.search_rounded, color: Colors.grey.shade700),
                onPressed: () => showSearchDialog(context),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 4),

            // Cart icon
            BlocSelector<CartCubit, CartState, int>(
              selector: (state) {
                if (state is CartLoaded) {
                  final total = state.data.summary.totalItems;
                  return total < 0 ? 0 : total;
                }
                return 0;
              },
              builder: (context, count) => AnimatedCartIcon(
                onTap: () => context.push('/cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}