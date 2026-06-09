import '../../../features/categories/data/models/category_models.dart';
import '../../../features/products/data/models/product_model.dart';
import '../data/models/search_models.dart';

sealed class SearchState {}

final class SearchInitial extends SearchState {}

final class SearchLoading extends SearchState {}

final class SearchSuccess extends SearchState {
  final SearchResponse result;

  /// null = show all categories; non-null = filter products to this category
  /// (including products that belong to any of its descendants).
  final int? selectedCategoryId;

  SearchSuccess(this.result, {this.selectedCategoryId});

  /// Products after applying the active category filter.
  ///
  /// Selecting a parent category (e.g. "Fruits & Vegetables") matches all
  /// products whose categoryId is that category OR any of its descendants
  /// (e.g. "Vegetables", id 18), because parent categories never hold products
  /// directly.
  List<ProductModel> get filteredProducts {
    if (selectedCategoryId == null) return result.products;

    final matchIds = _descendantIds(selectedCategoryId!, result.categories);
    return result.products
        .where((p) => matchIds.contains(p.categoryId))
        .toList();
  }

  /// Returns [parentId] plus the ids of every category in [all] that is a
  /// direct or indirect child of [parentId].
  static Set<int> _descendantIds(int parentId, List<CategoryModel> all) {
    final ids = <int>{parentId};
    for (final cat in all) {
      if (cat.parentId == parentId) {
        ids.addAll(_descendantIds(cat.id, all));
      }
    }
    return ids;
  }
}

final class SearchEmpty extends SearchState {}

final class SearchError extends SearchState {
  final String message;
  SearchError(this.message);
}
