import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/cart_response_model.dart';
import '../models/cart_item_model.dart';
import '../models/multiple_supplier_exception.dart';
import '../models/order_preview_model.dart';

enum CartUpdateAction { increment, decrement, set }

extension CartUpdateActionX on CartUpdateAction {
  String get value => name; // 'increment' | 'decrement' | 'set'
}

abstract class CartRemoteDataSource {
  Future<CartResponseModel> getCart();
  Future<CartItemModel> addItem({required int spId, required int quantity});
  Future<CartItemModel?> updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
  });
  Future<void> clearCart();

  Future<OrderPreviewModel> getOrderPreview(String? code);

}

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  final Dio _dio;

  CartRemoteDataSourceImpl() : _dio = ApiClient.instance.dio;

  @override
  Future<CartResponseModel> getCart() async {
    final response = await _dio.get('/cart?lang=${LocaleManager.currentLocale}');
    log('[Cart] GET /cart → ${response.statusCode}');
    return CartResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<OrderPreviewModel> getOrderPreview(String? code) async {
    final response = await _dio.post('/orders/preview?lang=${LocaleManager.currentLocale}',data: {if (code != null)'coupon_code': code});
    log('[Cart] GET /orders/preview → ${response.statusCode}');
    return OrderPreviewModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CartItemModel> addItem({
    required int spId,
    required int quantity,
  }) async {
    try {
      final response = await _dio.post(
        '/cart?lang=${LocaleManager.currentLocale}',
        data: {'sp_id': spId, 'quantity': quantity},
      );
      log('[Cart] POST /cart → ${response.statusCode}');
      final data = response.data as Map<String, dynamic>;
      return CartItemModel.fromJson(data['cartItem'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrowIfMultipleSuppliers(e, pendingSpId: spId, pendingQuantity: quantity);
      rethrow;
    }
  }

  @override
  Future<CartItemModel?> updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
  }) async {
    final response = await _dio.put(
      '/cart?lang=${LocaleManager.currentLocale}',
      data: {
        'sp_id': cartItemId,
        'action': action.value,
        'quantity': quantity,
      },
    );

    log('[Cart] PUT /cart → ${response.statusCode}');
    final data = response.data as Map<String, dynamic>;

    if (data['cartItem'] != null) {
      return CartItemModel.fromJson(
        data['cartItem'] as Map<String, dynamic>,
      );
    }

    // item removed case
    return null;
  }

  @override
  Future<void> clearCart() async {
    final response = await _dio.delete('/cart?lang=${LocaleManager.currentLocale}');
    log('[Cart] DELETE /cart → ${response.statusCode}');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Inspects a [DioException] response body for the `MULTIPLE_SUPPLIERS`
  /// error code. If found, throws a typed [MultipleSupplierException] instead
  /// of the raw Dio error so callers can distinguish this case easily.
  void _rethrowIfMultipleSuppliers(
      DioException e, {
        required int pendingSpId,
        required int pendingQuantity,
      }) {
    final body = e.response?.data;
    if (body is! Map<String, dynamic>) return;
    if (body['code'] != 'MULTIPLE_SUPPLIERS') return;

    final supplierData = body['data'] as Map<String, dynamic>?;
    if (supplierData == null) return;

    throw MultipleSupplierException(
      currentSupplierId: supplierData['current_supplier_id'] as int,
      attemptedSupplierId: supplierData['attempted_supplier_id'] as int,
      message: body['message'] as String? ?? 'Supplier conflict',
      pendingSpId: pendingSpId,
      pendingQuantity: pendingQuantity,
    );
  }
}