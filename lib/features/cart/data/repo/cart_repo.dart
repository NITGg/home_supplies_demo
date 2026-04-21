import '../data_source/cart_remote_data_source.dart';
import '../models/cart_item_model.dart';
import '../models/cart_response_model.dart';
import '../models/order_preview_model.dart';

// ── Abstract ──────────────────────────────────────────────────────────────────

abstract class CartRepository {
  Future<CartResponseModel> getCart();

  Future<CartItemModel> addItem({
    required int spId,
    required int quantity,
  });

  Future<CartItemModel?> updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
  });
  Future<OrderPreviewModel> getOrderPreview();


  Future<void> clearCart();
}

// ── Implementation ────────────────────────────────────────────────────────────

class CartRepositoryImpl implements CartRepository {
  final CartRemoteDataSource _dataSource;

  CartRepositoryImpl({CartRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? CartRemoteDataSourceImpl();

  @override
  Future<CartResponseModel> getCart() => _dataSource.getCart();

  @override
  Future<CartItemModel> addItem({
    required int spId,
    required int quantity,
  }) =>
      _dataSource.addItem(spId: spId, quantity: quantity);

  @override
  Future<CartItemModel?> updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
  }) =>
      _dataSource.updateItem(
        cartItemId: cartItemId,
        action: action,
        quantity: quantity,
      );

  Future<OrderPreviewModel> getOrderPreview() => _dataSource.getOrderPreview();

  @override
  Future<void> clearCart() => _dataSource.clearCart();
}