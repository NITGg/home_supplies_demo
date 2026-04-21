import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/style/app_colors.dart';
import '../../ads/presentation/widgets/home_ads_carousel.dart';
import '../../ads/presentation/widgets/popups.dart';
import '../data/models/category_models.dart';
import 'categories_grid_widget.dart';

/// Standalone screen that shows the full categories grid.
///
/// Owns the refresh key so pull-to-refresh works independently of
/// the orders screen. Navigation to category details is handled here
/// via go_router, exactly as it was when the grid lived in OrdersListScreen.
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
        child: SingleChildScrollView(
          // AlwaysScrollableScrollPhysics ensures the RefreshIndicator is
          // reachable even when the grid doesn't overflow the viewport.
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const PopupAdsHandler(),
              const HomeAdsCarousel(),
              CategoriesGridWidget(
                key: _categoriesKey,
                onCategoryTap: _navigateToCategory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}