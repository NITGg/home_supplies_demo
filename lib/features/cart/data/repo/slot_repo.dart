import 'package:dio/dio.dart';
import 'package:tawreedat_go/core/utils/api_client.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_go/core/utils/logger.dart';

import '../models/slot_model.dart';

// ── Product delivery windows repo ─────────────────────────────────────────────

class DeliveryWindowsRepository {
  /// Uses the supplier API (external base URL) — NOT the standard app base URL.
  static const _supplierBase =
      'https://tawreedatsupplierapis.nitg-eg.com/api/v1';

  final Dio _dio = ApiClient.instance.dio;

  /// Fetches ORDER and DELIVERY windows for [supplierProductId].
  ///
  /// The endpoint is on the supplier API host so we build the full URL
  /// explicitly rather than relying on the app's configured baseUrl.
  Future<ProductDeliveryWindowsData> fetchWindows(
      int supplierProductId,int supplierId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_supplierBase/supplier/product/get-supplier-product-delivery-windows/$supplierProductId/$supplierId',
      );
      return ProductDeliveryWindowsData.fromJson(response.data!);
    } on DioException catch (e) {
      dLog('[DeliveryWindowsRepo] DioException: ${e.message}');
      rethrow;
    } catch (e) {
      dLog('[DeliveryWindowsRepo] Unexpected error: $e');
      rethrow;
    }
  }
}

// ── Cart delivery slots repo ──────────────────────────────────────────────────

class CartDeliverySlotsRepository {
  final Dio _dio = ApiClient.instance.dio;

  /// Fetches available delivery time slots for [date].
  ///
  /// Pass the intended delivery date. The backend returns:
  ///   • is_scheduled_windows: bool — if false this cart is a normal cart
  ///   • slots: [{time_from, time_to, remaining}] — remaining = 0 means full
  Future<CartDeliverySlotsResponse> fetchSlots(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/orders/cart/delivery-slots',
        queryParameters: {'date': dateStr},
      );
      return CartDeliverySlotsResponse.fromJson(response.data!);
    } on DioException catch (e) {
      dLog('[CartDeliverySlotsRepo] DioException: ${e.message}');
      rethrow;
    } catch (e) {
      dLog('[CartDeliverySlotsRepo] Unexpected error: $e');
      rethrow;
    }
  }
}
