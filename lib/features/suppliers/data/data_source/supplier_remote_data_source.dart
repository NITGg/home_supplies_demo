
import 'package:dio/dio.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/supplier_models.dart';
import '../models/supplier_response_models.dart';

abstract class SupplierRemoteDataSource {
  /// Fetches a page of nearby suppliers, optionally filtered by [categoryId].
  Future<SuppliersResponseModel> getSuppliers({
    int? categoryId,
    int skip = 0,
    int limit = 20,
  });

  /// Fetches a single supplier's full detail.
  Future<SupplierModel> getSupplierById(int id);

  /// Fetches the list of categories served by a supplier.
  Future<SupplierCategoriesResponseModel> getSupplierCategories(int supplierId);
}

class SupplierRemoteDataSourceImpl implements SupplierRemoteDataSource {
  final Dio _dio;

  SupplierRemoteDataSourceImpl() : _dio = ApiClient.instance.dio;

  @override
  Future<SuppliersResponseModel> getSuppliers({
    int? categoryId,
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      if (categoryId != null) 'categories[some][category_id]': categoryId,
    };

    final response = await _dio.get(
      '/users/suppliers/nearby?includes=user,addresses&lang=${LocaleManager.currentLocale}',
      queryParameters: queryParams,
      data: LocationService.instance.latLngBody,
    );
    dLog('[SupplierDS] getSuppliers → ${response.data}');

    return SuppliersResponseModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  @override
  Future<SupplierModel> getSupplierById(int id) async {
    final response = await _dio.get('/users/suppliers/$id?lang=${LocaleManager.currentLocale}');
    final data = response.data as Map<String, dynamic>;
    dLog('[SupplierDS] getSupplierById($id) → $data');
    return SupplierModel.fromJson(data['supplier'] as Map<String, dynamic>);
  }

  @override
  Future<SupplierCategoriesResponseModel> getSupplierCategories(
      int supplierId) async {
    final response =
    await _dio.get('/users/suppliers/$supplierId/categories?lang=${LocaleManager.currentLocale}');
    dLog('[SupplierDS] getSupplierCategories($supplierId) → ${response.data}');
    return SupplierCategoriesResponseModel.fromJson(
        response.data as Map<String, dynamic>);
  }
}