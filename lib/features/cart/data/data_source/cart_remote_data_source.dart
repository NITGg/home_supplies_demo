import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/cart_response_model.dart';
import '../models/cart_item_model.dart';

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
}

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  final Dio _dio;

  CartRemoteDataSourceImpl() : _dio = ApiClient.instance.dioDEV;

  @override
  Future<CartResponseModel> getCart() async {
    final response = await _dio.get('/cart');
    log('[Cart] GET /cart → ${response.statusCode}');
    return CartResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CartItemModel> addItem({
    required int spId,
    required int quantity,
  }) async {
    final response = await _dio.post(
      '/cart',
      data: {'sp_id': spId, 'quantity': quantity},
    );
    log('[Cart] POST /cart → ${response.statusCode}');
    final data = response.data as Map<String, dynamic>;
    return CartItemModel.fromJson(data['cartItem'] as Map<String, dynamic>);
  }

  Future<CartItemModel?> updateItem({
    required int cartItemId,
    required CartUpdateAction action,
    required int quantity,
  }) async {
    final response = await _dio.put(
      '/cart',
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
    final response = await _dio.delete('/cart');
    log('[Cart] DELETE /cart → ${response.statusCode}');
  }
}