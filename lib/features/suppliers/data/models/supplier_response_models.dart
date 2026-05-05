import 'supplier_models.dart';

class SuppliersResponseModel {
  final List<SupplierModel> suppliers;

  const SuppliersResponseModel({required this.suppliers});

  factory SuppliersResponseModel.fromJson(Map<String, dynamic> json) {
    final result = (json['result'] ?? json) as Map<String, dynamic>;
    return SuppliersResponseModel(
      suppliers: (result['suppliers'] as List<dynamic>? ?? [])
          .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
          .toList(),
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