import 'supplier_models.dart';

class SuppliersResponseModel {
  final List<SupplierModel> suppliers;

  /// Total number of suppliers matching the query (across all pages).
  final int totalSuppliers;

  /// Total number of pages available for the requested page size.
  final int totalPages;

  const SuppliersResponseModel({
    required this.suppliers,
    required this.totalSuppliers,
    required this.totalPages,
  });

  factory SuppliersResponseModel.fromJson(Map<String, dynamic> json) {
    final result = (json['result'] ?? json) as Map<String, dynamic>;
    final suppliers = (result['suppliers'] as List<dynamic>? ?? [])
        .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // The backend may return the total count under a few different keys
    // depending on the endpoint version — fall back gracefully so pagination
    // degrades to "single page" instead of crashing if the field is absent.
    final total = (result['total'] ??
            result['totalSuppliers'] ??
            result['count'] ??
            suppliers.length) as num;

    return SuppliersResponseModel(
      suppliers: suppliers,
      totalSuppliers: total.toInt(),
      totalPages: (result['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class SupplierCategoriesResponseModel {
  final List<SupplierCategoryModel> categories;

  const SupplierCategoriesResponseModel({required this.categories});

  factory SupplierCategoriesResponseModel.fromJson(Map<String, dynamic> json) {
    return SupplierCategoriesResponseModel(
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) =>
          SupplierCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}