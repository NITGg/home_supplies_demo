import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../models/address_model.dart';

class AddressRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<AddressesResponse> getAddresses() async {
    try {
      final response = await _dio.get(
        '/profile/addresses',
      );

      log('Get addresses response: ${response.data}');

      if (response.statusCode == 200) {
        return AddressesResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load addresses');
      }
    } on DioException catch (e) {
      log('Get addresses error: $e');
      throw _handleError(e);
    }
  }

  Future<AddressOperationResponse> createAddress(Address address) async {
    try {
      log('Creating address: ${address.toJson()}');

      final response = await _dio.post(
        '/profile/addresses',
        data: address.toJson(),
      );

      log('Create address response: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AddressOperationResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to create address');
      }
    } on DioException catch (e) {
      log('Create address error: $e');
      throw _handleError(e);
    }
  }

  Future<AddressOperationResponse> updateAddress(
      int addressId,
      Address address,
      ) async {
    try {
      log('Updating address $addressId: ${address.toJson()}');

      final response = await _dio.put(
        '/profile/addresses/$addressId',
        data: address.toJson(),
      );

      log('Update address response: ${response.data}');

      if (response.statusCode == 200) {
        return AddressOperationResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to update address');
      }
    } on DioException catch (e) {
      log('Update address error: $e');
      throw _handleError(e);
    }
  }

  Future<void> deleteAddress(int addressId) async {
    try {
      log('Deleting address $addressId');

      final response = await _dio.delete(
        '/profile/addresses/$addressId',
      );

      log('Delete address response: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete address');
      }
    } on DioException catch (e) {
      log('Delete address error: $e');
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