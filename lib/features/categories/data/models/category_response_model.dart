import 'category_models.dart';

class CategoriesResponseModel {
  final int totalCount;
  final int totalPages;
  final List<CategoryModel> categories;

  const CategoriesResponseModel({
    required this.totalCount,
    required this.totalPages,
    required this.categories,
  });

  factory CategoriesResponseModel.fromJson(Map<String, dynamic> json) {
    return CategoriesResponseModel(
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}