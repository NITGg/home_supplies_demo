// search_model.dart

import '../../../categories/data/models/category_models.dart';
import '../../../products/data/models/product_model.dart';

class SearchResponse {
  final List<CategoryModel> categories;
  final List<ProductModel> products;

  const SearchResponse({
    required this.categories,
    required this.products,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      categories: (json['categories'] as List? ?? [])
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List? ?? [])
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEmpty => categories.isEmpty && products.isEmpty;
}