

// ── Abstract ──────────────────────────────────────────────────────────────────

import '../data_source/category_remote_data_source.dart';
import '../models/category_models.dart';
import '../models/category_response_model.dart';

abstract class CategoryRepository {
  Future<CategoriesResponseModel> getCategories({
    int skip = 0,
    int limit = 20,
    int? parentId,
  });

  Future<CategoryModel> getCategoryById(int id);
}

// ── Implementation ────────────────────────────────────────────────────────────

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource _dataSource;

  CategoryRepositoryImpl({CategoryRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? CategoryRemoteDataSourceImpl();

  @override
  Future<CategoriesResponseModel> getCategories({
    int skip = 0,
    int limit = 20,
    int? parentId,
  }) async {
    return await _dataSource.getCategories(
      skip: skip,
      limit: limit,
      parentId: parentId,
    );
  }

  @override
  Future<CategoryModel> getCategoryById(int id) async {
    return await _dataSource.getCategoryById(id);
  }
}