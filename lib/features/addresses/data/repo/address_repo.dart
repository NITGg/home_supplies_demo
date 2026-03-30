import '../data_source/address_remote_data_source.dart';
import '../models/address_model.dart';

class AddressRepository {
  final AddressRemoteDataSource _remoteDataSource;

  AddressRepository({AddressRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? AddressRemoteDataSource();

  Future<AddressesResponse> getAddresses() async {
    return await _remoteDataSource.getAddresses();
  }

  Future<AddressOperationResponse> createAddress(Address address) async {
    return await _remoteDataSource.createAddress(address);
  }

  Future<AddressOperationResponse> updateAddress(
    int addressId,
    Address address,
  ) async {
    return await _remoteDataSource.updateAddress(addressId, address);
  }

  Future<void> deleteAddress(int addressId) async {
    await _remoteDataSource.deleteAddress(addressId);
  }

  Future<void> createAddressUnAvailableRequest(
    bool isPickup,
    String long,
    String lat,
    String address,
    String area,
    String governorate,
  ) async {
    await _remoteDataSource.createAddressUnAvailableRequest(
      isPickup,
      long,
      lat,
      address,
      area,
      governorate,
    );
  }
}
