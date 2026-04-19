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
    String includes = 'attributes,units',
  });

  Future<ProductModel> getProductById(int id);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio _dio;

  ProductRemoteDataSourceImpl() : _dio = ApiClient.instance.dioDEV;

  @override
  Future<ProductsResponseModel> getProducts({
    int skip = 0,
    int limit = 20,
    int? categoryId,
    String includes = 'attributes,units',
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'includes': includes,
      if (categoryId != null) 'category_id': categoryId,
    };

    final response = await _dio.get(
      '/products',
      queryParameters: queryParams,
    );

    log(response.statusCode.toString());

    return ProductsResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ProductModel> getProductById(int id) async {
    final response = await _dio.get(
      '/products/$id',
      queryParameters: {'includes': 'attributes,units'},
    );

    final data = response.data as Map<String, dynamic>;
    log(data.toString());
    return ProductModel.fromJson(data['product'] as Map<String, dynamic>);
  }
}