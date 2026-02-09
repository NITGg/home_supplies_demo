import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/orders_model.dart';

class OrderDataSource {
  final ApiClient _apiClient = ApiClient.instance;

  /// Get available orders (pending orders) with pagination
  Future<Map<String, dynamic>> getAvailableOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/order/available-orders',
        queryParameters: {'page': page, 'limit': limit, 'lang': 'ar'},
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

  /// Get order history with filters and pagination
  Future<Map<String, dynamic>> getOrderHistory({
    int page = 1,
    int limit = 20,
    String filter = 'all', // all, completed, cancelled
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/order/history',
        queryParameters: {
          'filter': filter,
          'page': page,
          'limit': limit,
          'lang': 'ar',
        },
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
        queryParameters: {'lang': 'ar'},
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
        queryParameters: {'lang': 'ar'},
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
        queryParameters: {'lang': 'ar'},
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
      final response = await _apiClient.dio.get(
        '/order/active-order',
        queryParameters: {'lang': 'ar'},
      );

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
        queryParameters: {'lang': 'ar'},
        data: {'actual_price': actualPrice},
      );

      return QrCodeModel.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Report high price (budget not enough)
  Future<OrderModel> reportHighPrice({
    required int orderId,
    required double actualPrice,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/report-order-high-price/$orderId',
        queryParameters: {'lang': 'ar'},
        data: {'actual_price': actualPrice},
      );

      return OrderModel.fromJson(response.data['data']['order']);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel order - product unavailable
  Future<OrderModel> cancelOrderUnavailable({
    required int orderId,
    required String note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/cancel-unavailable/$orderId',
        queryParameters: {'lang': 'ar'},
        data: {'note': note},
      );

      return OrderModel.fromJson(response.data['data']['order']);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel order - other reason
  Future<OrderModel> cancelOrderOther({
    required int orderId,
    required String note,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/order/cancel-other/$orderId',
        queryParameters: {'lang': 'ar'},
        data: {'note': note},
      );

      return OrderModel.fromJson(response.data['data']['order']);
    } catch (e) {
      rethrow;
    }
  }
}
