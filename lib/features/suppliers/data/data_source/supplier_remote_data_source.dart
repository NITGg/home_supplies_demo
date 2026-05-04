import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/supplier_models.dart';
import '../models/supplier_response_models.dart';

abstract class SupplierRemoteDataSource {
  /// Fetches all suppliers, optionally filtered by [categoryId].
  Future<SuppliersResponseModel> getSuppliers({int? categoryId});

  /// Fetches a single supplier's full detail.
  Future<SupplierModel> getSupplierById(int id);

  /// Fetches the list of categories served by a supplier.
  Future<SupplierCategoriesResponseModel> getSupplierCategories(int supplierId);
}

class SupplierRemoteDataSourceImpl implements SupplierRemoteDataSource {
  final Dio _dio;

  SupplierRemoteDataSourceImpl() : _dio = ApiClient.instance.dio;

  @override
  Future<SuppliersResponseModel> getSuppliers({int? categoryId}) async {
    final queryParams = <String, dynamic>{
      if (categoryId != null) 'category_id': categoryId,
    };

    final response = await _dio.get(
      '/users/suppliers?is_approved=true&lang=${LocaleManager.currentLocale}',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    log('[SupplierDS] getSuppliers → ${response.data}');

    return SuppliersResponseModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  @override
  Future<SupplierModel> getSupplierById(int id) async {
    final response = await _dio.get('/users/suppliers/$id?lang=${LocaleManager.currentLocale}');
    final data = response.data as Map<String, dynamic>;
    log('[SupplierDS] getSupplierById($id) → $data');
    return SupplierModel.fromJson(data['supplier'] as Map<String, dynamic>);
  }

  @override
  Future<SupplierCategoriesResponseModel> getSupplierCategories(
      int supplierId) async {
    final response =
    await _dio.get('/users/suppliers/$supplierId/categories?is_approved=true&lang=${LocaleManager.currentLocale}');
    log('[SupplierDS] getSupplierCategories($supplierId) → ${response.data}');
    return SupplierCategoriesResponseModel.fromJson(
        response.data as Map<String, dynamic>);
  }
}