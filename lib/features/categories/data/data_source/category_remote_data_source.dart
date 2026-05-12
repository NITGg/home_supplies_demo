
import 'package:dio/dio.dart';
import 'package:tawreedat_go/core/utils/logger.dart';

import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/category_models.dart';
import '../models/category_response_model.dart';


abstract class CategoryRemoteDataSource {
  Future<CategoriesResponseModel> getCategories({
    int skip = 0,
    int limit = 20,
    int? parentId,
  });

  Future<CategoryModel> getCategoryById(int id);
}

class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final Dio _dio;

  CategoryRemoteDataSourceImpl() : _dio = ApiClient.instance.dio;

  @override
  Future<CategoriesResponseModel> getCategories({
    int skip = 0,
    int limit = 20,
    int? parentId,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      if (parentId != null) 'parent_id': parentId,
    };

    final response = await _dio.get(
      '/categories?lang=${LocaleManager.currentLocale}',
      queryParameters: queryParams,
    );
    dLog(response.data.toString());

    return CategoriesResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<CategoryModel> getCategoryById(int id) async {
    final response = await _dio.get('/categories/$id?lang=${LocaleManager.currentLocale}');
    final data = response.data as Map<String, dynamic>;
    dLog(data.toString());
    return CategoryModel.fromJson(data['category'] as Map<String, dynamic>);
  }
}