import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../models/address_model.dart';

class AddressRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<AddressesResponse> getAddresses() async {
    final response = await _dio.get('/profile/addresses');
    if (response.statusCode == 200) {
      return AddressesResponse.fromJson(response.data);
    }
    throw Exception('Failed to load addresses');
  }

  Future<AddressOperationResponse> createAddress(Address address) async {
    final response = await _dio.post(
      '/profile/addresses',
      data: address.toJson(),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return AddressOperationResponse.fromJson(response.data);
    }
    throw Exception('Failed to create address');
  }

  Future<AddressOperationResponse> updateAddress(
    int addressId,
    Address address,
  ) async {
    final response = await _dio.put(
      '/profile/addresses/$addressId',
      data: address.toJson(),
    );
    if (response.statusCode == 200) {
      return AddressOperationResponse.fromJson(response.data);
    }
    throw Exception('Failed to update address');
  }

  Future<void> deleteAddress(int addressId) async {
    final response = await _dio.delete('/profile/addresses/$addressId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete address');
    }
  }

}
