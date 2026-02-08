import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/orders_model.dart';

class OrderDataSource {
  final ApiClient _apiClient = ApiClient.instance;

  /// Get available orders (pending orders)
  Future<Map<String, dynamic>> getAvailableOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/order/available-orders',
        queryParameters: {'page': page, 'limit': limit},
      );

      final orders = (response.data['data']['orders'] as List)
          .map((order) => OrderModel.fromJson(order))
          .toList();

      return {
        'orders': orders,
        'pagination': response.data['data']['pagination'],
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get order details by ID
  Future<OrderModel> getOrderDetails(int orderId) async {
    try {
      final response = await _apiClient.dio.get(
        '/order/order-details/$orderId',
      );

      return OrderModel.fromJson(response.data['data']['order']);
    } catch (e) {
      rethrow;
    }
  }

  /// Get allowed fee range for an order
  Future<FeeRangeModel> getAllowedFeeRange(int orderId) async {
    try {
      final response = await _apiClient.dio.get(
        '/order/allowed-fee-range/$orderId',
      );

      return FeeRangeModel.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Submit offer (proposal) for an order
  Future<ProposalModel> submitOffer({
    required int orderId,
    required double totalFee,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/submit-offer/$orderId',
        data: {'total_fee': totalFee},
      );

      return ProposalModel.fromJson(response.data['data']['proposal']);
    } catch (e) {
      rethrow;
    }
  }

  /// Get active order (order in progress)
  Future<OrderModel?> getActiveOrder() async {
    try {
      final response = await _apiClient.dio.get('/order/active-order');

      if (response.data['data']['order'] == null) {
        return null;
      }

      return OrderModel.fromJson(response.data['data']['order']);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Complete delivery and get QR code
  Future<QrCodeModel> completeDelivery({
    required int orderId,
    required double actualPrice,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/complete-delivery/$orderId',
        data: {'actual_price': actualPrice},
      );

      return QrCodeModel.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }
}
