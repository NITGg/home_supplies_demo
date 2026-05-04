import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
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

  Future<ProductModel> getProductById(int id, {int? supplierId});
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
      'supplier_id': supplierId ?? AppSettings.kMainSupplierId,
      if (categoryId != null) 'product[category_id]': categoryId,
      if (isFeatured != null) 'is_featured': isFeatured,
      if (isLastPurchased != null) 'last_bought': isLastPurchased,
    };

    final response = await _dio.get(
      '/products?lang=${LocaleManager.currentLocale}',
      queryParameters: queryParams,
    );

    log(response.statusCode.toString());
    log(response.data.toString());

    return ProductsResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<ProductModel> getProductById(int id, {int? supplierId}) async {
    final sid = supplierId ?? AppSettings.kMainSupplierId;
    final response = await _dio.get(
      '/products/$id?lang=${LocaleManager.currentLocale}&supplier_id=$sid&include=attributes',
    );

    final data = response.data as Map<String, dynamic>;
    log(data.toString());
    return ProductModel.fromJson(data['product'] as Map<String, dynamic>);
  }
}