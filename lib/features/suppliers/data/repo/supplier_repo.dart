import '../data_source/supplier_remote_data_source.dart';
import '../models/supplier_models.dart';
import '../models/supplier_response_models.dart';

// ── Abstract ──────────────────────────────────────────────────────────────────

abstract class SupplierRepository {
  Future<SuppliersResponseModel> getSuppliers({
    int? categoryId,
    int skip = 0,
    int limit = 20,
  });

  Future<SupplierModel> getSupplierById(int id);

  Future<SupplierCategoriesResponseModel> getSupplierCategories(
      int supplierId);
}

// ── Implementation ────────────────────────────────────────────────────────────

class SupplierRepositoryImpl implements SupplierRepository {
  final SupplierRemoteDataSource _dataSource;

  SupplierRepositoryImpl({SupplierRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? SupplierRemoteDataSourceImpl();

  @override
  Future<SuppliersResponseModel> getSuppliers({
    int? categoryId,
    int skip = 0,
    int limit = 20,
  }) =>
      _dataSource.getSuppliers(categoryId: categoryId, skip: skip, limit: limit);

  @override
  Future<SupplierModel> getSupplierById(int id) =>
      _dataSource.getSupplierById(id);

  @override
  Future<SupplierCategoriesResponseModel> getSupplierCategories(
      int supplierId) =>
      _dataSource.getSupplierCategories(supplierId);
}