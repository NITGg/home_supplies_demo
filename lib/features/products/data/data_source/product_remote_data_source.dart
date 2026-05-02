// ── PATCH: add supplierId parameter to getProducts ───────────────────────────
// Apply this diff to your existing product_remote_data_source.dart
// and product_repo.dart files.
//
// In ProductRemoteDataSource (abstract):
//   Future<ProductsResponseModel> getProducts({
//     int skip = 0,
//     int limit = 20,
//     int? categoryId,
//     bool? isFeatured,
//     bool? isLastPurchased,
//     int? supplierId,          // ← ADD THIS
//   });
//
// In ProductRemoteDataSourceImpl.getProducts():
//   final queryParams = <String, dynamic>{
//     'skip': skip,
//     'limit': limit,
//     'supplier_id': supplierId ?? 9,   // ← REPLACE hard-coded 9 with this
//     if (categoryId != null) 'product[category_id]': categoryId,
//     if (isFeatured != null) 'is_featured': isFeatured,
//     if (isLastPurchased != null) 'last_bought': isLastPurchased,
//   };
//
// In ProductRepository (abstract) + ProductRepositoryImpl:
//   Same signature addition:  int? supplierId
//   Pass it through to _dataSource.getProducts(... supplierId: supplierId)

// ─────────────────────────────────────────────────────────────────────────────
// Full updated files below:
// ─────────────────────────────────────────────────────────────────────────────

// product_remote_data_source.dart
import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/product_model.dart';
import '../models/product_response_model.dart';

abstract class ProductRemoteDataSource {
  Future<ProductsResponseModel> getProducts({
    int skip = 0,
    int limit = 20,
    int? categoryId,
    bool? isFeatured,
    bool? isLastPurchased,
    int? supplierId,
  });

  Future<ProductModel> getProductById(int id);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _dio;

  ProductRemoteDataSourceImpl() : _dio = ApiClient.instance.dio;

  @override
  Future<ProductsResponseModel> getProducts({
    int skip = 0,
    int limit = 20,
    int? categoryId,
    bool? isFeatured,
    bool? isLastPurchased,
    int? supplierId,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'supplier_id': supplierId ?? 9, // default to Tawreedat Go
      if (categoryId != null) 'product[category_id]': categoryId,
      if (isFeatured != null) 'is_featured': isFeatured,
      if (isLastPurchased != null) 'last_bought': isLastPurchased,
    };

    final response = await _dio.get(
      '/products',
      queryParameters: queryParams,
    );

    log(response.statusCode.toString());
    log(response.data.toString());

    return ProductsResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ProductModel> getProductById(int id) async {
    final response = await _dio.get(
      '/products/$id?supplier_id=9&include=attributes',
    );

    final data = response.data as Map<String, dynamic>;
    log(data.toString());
    return ProductModel.fromJson(data['product'] as Map<String, dynamic>);
  }
}