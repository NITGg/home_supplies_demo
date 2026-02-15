import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/socket_service.dart';
import '../models/order_model.dart';
import '../models/proposal_model.dart';
import '../models/qr_model.dart';

class OrderRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  // Create Order
  Future<OrderResponse> createOrder(Order order) async {
    try {
      log('Creating order: ${order.toJson()}');

      FormData formData;

      if (order.productImageFile != null) {
        formData = FormData.fromMap({
          'product_description': order.productDescription,
          'budget': order.budget,
          'pickup_area_id': order.pickupAreaId,
          'pickup_address_description': order.pickupAddressDescription,
          'pickup_lat': order.pickupLat,
          'pickup_long': order.pickupLong,
          'delivery_area_id': order.deliveryAreaId,
          'delivery_address_description': order.deliveryAddressDescription,
          'delivery_lat': order.deliveryLat,
          'delivery_long': order.deliveryLong,
          'product_image': await MultipartFile.fromFile(
            order.productImageFile!.path,
            filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        });
      } else {
        formData = FormData.fromMap(order.toJson());
      }

      final response = await _dio.post('/orders', data: formData);

      log('Create order response: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        SocketService().joinOrder(response.data['order']['id']);
        return OrderResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to create order');
      }
    } on DioException catch (e) {
      log('Create order error: $e');
      throw _handleError(e);
    }
  }

  // Get All Orders
  Future<OrdersListResponse> getOrders({
    int skip = 0,
    int limit = 20,
    String? status,
  }) async {
    try {
      log('Fetching orders - skip: $skip, limit: $limit, status: $status');

      final response = await _dio.get(
        '/orders',
        queryParameters: {
          'skip': skip,
          'limit': limit,
          if (status != null) 'status': status,
        },
      );

      log('Get orders response: ${response.data}');

      if (response.statusCode == 200) {
        return OrdersListResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load orders');
      }
    } on DioException catch (e) {
      log('Get orders error: $e');
      throw _handleError(e);
    }
  }

  // Cancel Order
  Future<void> cancelOrder(int orderId, String reason) async {
    try {
      log('Cancelling order $orderId with reason: $reason');

      final response = await _dio.post(
        '/orders/$orderId/cancel',
        data: {'cancelled_reason': reason},
      );

      log('Cancel order response: ${response.data}');

      if (response.statusCode == 200) {
      } else {
        throw Exception('Failed to cancel order');
      }
    } on DioException catch (e) {
      log('Cancel order error: $e');
      throw _handleError(e);
    }
  }

  // Get Proposals for an Order
  Future<ProposalsResponse> getOrderProposals(int orderId) async {
    try {
      log('Fetching proposals for order $orderId');

      final response = await _dio.get('/orders/$orderId/proposals');

      log('Get proposals response: ${response.data}');

      if (response.statusCode == 200) {
        return ProposalsResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load proposals');
      }
    } on DioException catch (e) {
      log('Get proposals error: $e');
      throw _handleError(e);
    }
  }

  // Accept or Reject Proposal
  Future<Map<String, dynamic>> updateProposalStatus({
    required int orderId,
    required int proposalId,
    required String status, // ACCEPTED or REJECTED
  }) async {
    try {
      log('Updating proposal $proposalId status to $status');

      final response = await _dio.put(
        '/orders/$orderId/proposals/$proposalId',
        data: {'status': status},
      );

      log('Update proposal response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to update proposal');
      }
    } on DioException catch (e) {
      log('Update proposal error: $e');
      throw _handleError(e);
    }
  }

  // Confirm Delivery (from QR Code scan)
  Future<Map<String, dynamic>> confirmDelivery({
    required int orderId,
    required int courierId,
  }) async {
    try {
      log('Confirming delivery for order $orderId by courier $courierId');

      final request = ConfirmDeliveryRequest(
        orderId: orderId,
        courierId: courierId,
      );

      final response = await _dio.post(
        '/orders/confirm-delivery',
        data: request.toJson(),
      );

      log('Confirm delivery response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to confirm delivery');
      }
    } on DioException catch (e) {
      log('Confirm delivery error: $e');
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final message =
          e.response?.data['message'] ??
          e.response?.data['error'] ??
          'An error occurred';
      return message;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}
