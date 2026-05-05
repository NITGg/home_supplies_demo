import '../../data/models/product_model.dart';
import '../data_source/product_remote_data_source.dart';
import '../models/product_response_model.dart';

// ── Abstract ──────────────────────────────────────────────────────────────────

abstract class ProductRepository {
  Future<ProductsResponseModel> getProducts({
    int skip = 0,
    int limit = 20,
    int? categoryId,
    bool? isFeatured,
    bool? isBestSelling,
    bool? isOffered,
    bool? isLastPurchased,
    int? supplierId,
  });

  Future<ProductModel> getProductById(int id, {int? supplierId});
}

// ── Implementation ────────────────────────────────────────────────────────────

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource _dataSource;

  ProductRepositoryImpl({ProductRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? ProductRemoteDataSourceImpl();

  @override
  Future<ProductsResponseModel> getProducts({
    int skip = 0,
    int limit = 20,
    int? categoryId,
    bool? isFeatured,
    bool? isBestSelling,
    bool? isOffered,
    bool? isLastPurchased,
    int? supplierId,
  }) async {
    return await _dataSource.getProducts(
      skip: skip,
      limit: limit,
      categoryId: categoryId,
      isFeatured: isFeatured,
      isLastPurchased: isLastPurchased,
      supplierId: supplierId,
      isBestSelling: isBestSelling,
      isOffered: isOffered,
    );
  }

  @override
  Future<ProductModel> getProductById(int id, {int? supplierId}) async {
    return await _dataSource.getProductById(id, supplierId: supplierId);
  }
}