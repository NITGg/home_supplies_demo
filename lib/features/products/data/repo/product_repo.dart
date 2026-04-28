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
    bool? isLastPurchased,
  });

  Future<ProductModel> getProductById(int id);
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
    bool? isLastPurchased,
  }) async {
    return await _dataSource.getProducts(
      skip: skip,
      limit: limit,
      categoryId: categoryId,
      isFeatured: isFeatured,
      isLastPurchased: isLastPurchased,
    );
  }

  @override
  Future<ProductModel> getProductById(int id) async {
    return await _dataSource.getProductById(id);
  }
}