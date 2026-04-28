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
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'supplier_id': 9, // tawreedat go = 9
      if (categoryId != null) 'category_id': categoryId,
      if (isFeatured != null) 'is_featured': isFeatured,
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