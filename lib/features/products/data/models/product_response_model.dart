import 'product_model.dart';

class ProductsResponseModel {
  final List<ProductModel> products;
  final int totalProducts;
  final int totalPages;

  const ProductsResponseModel({
    required this.products,
    required this.totalProducts,
    required this.totalPages,
  });

  factory ProductsResponseModel.fromJson(Map<String, dynamic> json) {
    return ProductsResponseModel(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalProducts: json['totalProducts'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}