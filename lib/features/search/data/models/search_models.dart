// search_model.dart

import '../../../categories/data/models/category_models.dart';
import '../../../products/data/models/product_model.dart';
import '../../../suppliers/data/models/supplier_models.dart';

class SearchResponse {
  final List<CategoryModel> categories;
  final List<ProductModel> products;

  /// supplierId → SupplierModel. Populated when the API includes supplier data.
  final Map<int, SupplierModel> suppliersById;

  const SearchResponse({
    required this.categories,
    required this.products,
    this.suppliersById = const {},
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final rawSPs = json['supplierProducts'] as List? ?? [];

    // New API returns products directly inside supplierProducts
    final List<ProductModel> products = rawSPs
        .map((e) => ProductModel.fromSearchJson(e as Map<String, dynamic>))
        .toList();

    final suppliersById = <int, SupplierModel>{};

    for (final sp in rawSPs) {
      final map = sp as Map<String, dynamic>;

      final supplierData =
      map['supplier_data'] as Map<String, dynamic>?;

      final supplierJson =
      supplierData?['supplier'] as Map<String, dynamic>?;

      if (supplierJson == null) continue;

      final id = supplierJson['id'] as int?;

      if (id == null || suppliersById.containsKey(id)) continue;

      final userJson =
          supplierJson['user'] as Map<String, dynamic>? ?? {};

      suppliersById[id] = SupplierModel(
        id: id,
        isApproved: true,
        synonyms: null,
        user: SupplierUserModel(
          id: userJson['id'] as int? ?? 0,
          fullName: userJson['full_name'] as String? ?? '',
          phone: '',
          personalPhoto: userJson['personal_photo'] as String?,
        ),
        categories: [],
        addresses: [],
        avgRating: 0,
      );
    }

    return SearchResponse(
      categories: (json['categories'] as List? ?? [])
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: products,
      suppliersById: suppliersById,
    );
  }

  bool get isEmpty => categories.isEmpty && products.isEmpty;
}