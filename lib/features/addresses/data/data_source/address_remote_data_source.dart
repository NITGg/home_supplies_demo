
import 'package:dio/dio.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../models/address_model.dart';

class AddressRemoteDataSource {
  final Dio _dio = ApiClient.instance.dio;

  Future<AddressesResponse> getAddresses() async {
    final response = await _dio.get(
      '/profile/addresses?lang=${LocaleManager.currentLocale}',
    );
    if (response.statusCode == 200) {
      return AddressesResponse.fromJson(response.data);
    }
    throw Exception('Failed to load addresses');
  }

  Future<AddressOperationResponse> createAddress(Address address) async {
    final response = await _dio.post(
      '/profile/addresses?lang=${LocaleManager.currentLocale}',
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
      '/profile/addresses/$addressId?lang=${LocaleManager.currentLocale}',
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

  Future<void> createAddressUnAvailableRequest(
    bool isPickup,
    String long,
    String lat,
    String address,
    String area,
    String governorate,
  ) async {
    final requestType = isPickup ? 'PICKUP' : 'DELIVERY';
    final response = await _dio.post(
      '/unavailable-area-request?lang=${LocaleManager.currentLocale}',
      data: {
        "request_type": requestType,
        "lat": lat,
        "long": long,
        "address": address,
        "area": area,
        "governorate": governorate,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create address');
    }
  }
}
