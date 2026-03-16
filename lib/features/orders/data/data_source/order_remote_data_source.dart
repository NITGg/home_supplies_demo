import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/order_model.dart';
import '../models/proposal_model.dart';
import '../models/qr_model.dart';

class OrderRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  // Create Order
  Future<OrderResponse> createOrder(
    Order order,
    String paymentMethod, {
    String? couponCode,
  }) async {
    log('Creating order: ${order.toJson()} payment method: $paymentMethod');

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
        'payment_method': paymentMethod,
        if (couponCode != null) 'coupon_code': couponCode,
        'product_image': await MultipartFile.fromFile(
          order.productImageFile!.path,
          filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });
    } else {
      formData = FormData.fromMap({
        ...order.toJson(),
        'payment_method': paymentMethod,
        if (couponCode != null) 'coupon_code': couponCode,
      });
    }

    final response = await _dio.post(
      '/orders?lang=${LocaleManager.currentLocale}',
      data: formData,
    );

    log('Create order response: ${response.data}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return OrderResponse.fromJson(response.data);
    } else {
      throw Exception('Failed to create order');
    }
  }

  // Get All Orders
  Future<OrdersListResponse> getOrders({
    int skip = 0,
    int limit = 20,
    String? status,
  }) async {
    log('Fetching orders - skip: $skip, limit: $limit, status: $status');

    final response = await _dio.get(
      '/orders?includes=courier=user',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'lang': LocaleManager.currentLocale,
        if (status != null) 'status': status,
      },
    );

    log('Get orders response: ${response.data}');

    if (response.statusCode == 200) {
      return OrdersListResponse.fromJson(response.data);
    } else {
      throw Exception('Failed to load orders');
    }
  }

  // Cancel Order
  Future<void> cancelOrder(int orderId, String reason) async {
    log('Cancelling order $orderId with reason: $reason');

    final response = await _dio.post(
      '/orders/$orderId/cancel?lang=${LocaleManager.currentLocale}',
      data: {'cancelled_reason': reason},
    );

    log('Cancel order response: ${response.data}');

    if (response.statusCode == 200) {
    } else {
      throw Exception('Failed to cancel order');
    }
  }

  // Get Proposals for an Order
  Future<ProposalsResponse> getOrderProposals(int orderId) async {
    log('Fetching proposals for order $orderId');

    final response = await _dio.get(
      '/orders/$orderId/proposals?lang=${LocaleManager.currentLocale}',
    );

    log('Get proposals response: ${response.data}');

    if (response.statusCode == 200) {
      return ProposalsResponse.fromJson(response.data);
    } else {
      throw Exception('Failed to load proposals');
    }
  }

  // Accept or Reject Proposal
  Future<Map<String, dynamic>> updateProposalStatus({
    required int orderId,
    required int proposalId,
    required String status, // ACCEPTED or REJECTED
  }) async {
    log('Updating proposal $proposalId status to $status');

    final response = await _dio.put(
      '/orders/$orderId/proposals/$proposalId?lang=${LocaleManager.currentLocale}',
      data: {'status': status},
    );

    log('Update proposal response: ${response.data}');

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to update proposal');
    }
  }

  // Confirm Delivery (from QR Code scan)
  Future<Map<String, dynamic>> confirmDelivery({
    required int orderId,
    required int courierId,
  }) async {
    log('Confirming delivery for order $orderId by courier $courierId');

    final request = ConfirmDeliveryRequest(
      orderId: orderId,
      courierId: courierId,
    );

    final response = await _dio.post(
      '/orders/confirm-delivery?lang=${LocaleManager.currentLocale}',
      data: request.toJson(),
    );

    log('Confirm delivery response: ${response.data}');

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to confirm delivery');
    }
  }

  // Validate coupon
  Future<Map<String, dynamic>> validateCoupon(String code) async {
    final response = await _dio.post(
      '/customer-coupons/validate?lang=${LocaleManager.currentLocale}',
      data: {'code': code},
    );
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to validate coupon');
    }
  }

  // Add this method to OrderRemoteDataSource

  Future<Map<String, dynamic>> respondToPriceAdjustment({
    required int orderId,
    required String status, // 'ACCEPTED' or 'REJECTED'
  }) async {
    log(
      'Responding to price adjustment for order $orderId with status: $status',
    );

    final response = await _dio.put(
      '/orders/$orderId/price-adjustment?lang=${LocaleManager.currentLocale}',
      data: {'status': status},
    );

    log('Price adjustment response: ${response.data}');

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to respond to price adjustment');
    }
  }

  // Redeem coupon
  Future<Map<String, dynamic>> redeemCoupon(String code) async {
    final response = await _dio.post(
      '/profile/wallet/coupon/redeem?lang=${LocaleManager.currentLocale}',
      data: {'code': code},
    );
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to redeem coupon');
    }
  }
}
