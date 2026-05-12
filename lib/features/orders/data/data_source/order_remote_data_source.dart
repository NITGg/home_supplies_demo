import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../../../auth/data/data_sources/auth_remote_data_source.dart';
import '../models/order_model.dart';
import '../models/proposal_model.dart';
import '../models/qr_model.dart';

class OrderRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;
  static const _allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  Future<void> _validateImage(File file) async {
    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(file.path, headerBytes: bytes);
    if (!_allowedMimeTypes.contains(mimeType)) {
      throw const ImageValidationException(
        'Only JPEG, PNG, or WEBP images are allowed',
      );
    }
  }
  // Create Order
  Future<OrderResponse> createOrder(
    Order order,
    String paymentMethod, {
      required String estimatedDeliveryFee,
    String? couponCode,
  }) async {
    dLog('Creating order: ${order.toJson()} payment method: $paymentMethod coupon code: $couponCode, estimated delivery fee: $estimatedDeliveryFee');
    if (order.productImageFile != null) {
      await _validateImage(order.productImageFile!);
    }
    FormData formData;

    if (order.productImageFile != null) {
      formData = FormData.fromMap({
        'type' : 'CUSTOM_PICKUP',
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
        'estemated_delivery_fee': estimatedDeliveryFee,

        if (couponCode != null) 'coupon_code': couponCode,
        'product_image': await MultipartFile.fromFile(
          order.productImageFile!.path,
          filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });
    } else {
      formData = FormData.fromMap({
        ...order.toJson(),
        'type' : 'CUSTOM_PICKUP',
        'payment_method': paymentMethod,
        if (couponCode != null) 'coupon_code': couponCode,
        'estemated_delivery_fee': estimatedDeliveryFee,
      });
    }
    dLog('Form data: ${formData.fields}');

    final response = await _dio.post(
      '/orders?lang=${LocaleManager.currentLocale}',
      data: formData,
    );

    dLog('Create order response: ${response.data}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return OrderResponse.fromJson(response.data);
    } else {
      throw Exception('Failed to create order');
    }
  }


  Future<OrderResponse> createCatalogOrder({
    required String paymentMethod,
    String? couponCode,
  }) async {
    dLog('Creating catalog order — payment: $paymentMethod, coupon: $couponCode');

    final response = await _dio.post(
      '/orders?lang=${LocaleManager.currentLocale}',
      data: {
        'type': 'CATALOG_PURCHASE',
        'payment_method': paymentMethod,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
      },
      options: Options()
    );

    dLog('Create catalog order response: ${response.data}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return OrderResponse.fromJson(response.data);
    } else {
      throw Exception('Failed to create catalog order');
    }
  }

  // Get All Orders
  Future<OrdersListResponse> getOrders({
    int skip = 0,
    int limit = 20,
    String? status,
    bool filterByExpiry = true,
  }) async {
    dLog('Fetching orders - skip: $skip, limit: $limit, status: $status, filterByExpiry: $filterByExpiry');

    final queryParams = {
      'skip': skip,
      'limit': limit,
      'includes': 'courier=user',
      'lang': LocaleManager.currentLocale,
      if (status != null) 'status': status,
      if (filterByExpiry)
        'expires_at[gte]': DateTime.now().toUtc(),
    };

    final response = await _dio.get(
      '/orders',
      queryParameters: queryParams,
    );

    dLog('Get orders response: ${response.data}');

    if (response.statusCode == 200) {
      return OrdersListResponse.fromJson(response.data);
    } else {
      throw Exception('Failed to load orders');
    }
  }

  // Cancel Order
  Future<void> cancelOrder(int orderId, String reason) async {
    dLog('Cancelling order $orderId with reason: $reason');

    final response = await _dio.post(
      '/orders/$orderId/cancel?lang=${LocaleManager.currentLocale}',
      data: {'cancelled_reason': reason},
    );

    dLog('Cancel order response: ${response.data}');

    if (response.statusCode == 200) {
    } else {
      throw Exception('Failed to cancel order');
    }
  }

  // Get Proposals for an Order
  Future<ProposalsResponse> getOrderProposals(int orderId) async {
    dLog('Fetching proposals for order $orderId');

    final response = await _dio.get(
      '/orders/$orderId/proposals?lang=${LocaleManager.currentLocale}',
    );

    dLog('Get proposals response: ${response.data}');

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
    dLog('Updating proposal $proposalId status to $status');

    final response = await _dio.put(
      '/orders/$orderId/proposals/$proposalId?lang=${LocaleManager.currentLocale}',
      data: {'status': status},
    );

    dLog('Update proposal response: ${response.data}');

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
    dLog('Confirming delivery for order $orderId by courier $courierId');

    final request = ConfirmDeliveryRequest(
      orderId: orderId,
      courierId: courierId,
    );

    final response = await _dio.post(
      '/orders/confirm-delivery?lang=${LocaleManager.currentLocale}',
      data: request.toJson(),
    );

    dLog('Confirm delivery response: ${response.data}');

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to confirm delivery');
    }
  }

  // Validate coupon
  Future<Map<String, dynamic>> validateCoupon(String code,bool customOrder) async {
    final response = await _dio.post(
      '/customer-coupons/validate?lang=${LocaleManager.currentLocale}',
      data: {'code': code,'orderType' : customOrder ? 'CUSTOM_PICKUP' : 'CATALOG_PURCHASE'},
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

    dLog('Price adjustment response: ${response.data}');

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

  Future<Map<String, dynamic>> retryOrder(int orderId) async {
    dLog('Retrying order $orderId');
    final response = await _dio.post(
      '/orders/$orderId/retry?lang=${LocaleManager.currentLocale}',
    );
    dLog('Retry order response: ${response.data}');
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to retry order');
    }
  }
}
