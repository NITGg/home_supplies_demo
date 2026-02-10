import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../models/order_model.dart';

class OrderRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<OrderResponse> createOrder(Order order) async {
    try {
      log('Creating order: ${order.toJson()}');

      FormData formData;

      // If there's an image file, use FormData for multipart upload
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
        // If no image file, send regular JSON
        formData = FormData.fromMap(order.toJson());
      }

      final response = await _dio.post(
        '/orders',
        data: order.toJson(),
      );

      log('Create order response: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return OrderResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to create order');
      }
    } on DioException catch (e) {
      log('Create order error: $e');
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final message = e.response?.data['message'] ??
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