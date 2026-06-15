import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/secure_storage_service.dart';
import '../../../core/utils/safe_emit_mixin.dart';
import '../data/models/address_model.dart';
import '../data/repo/address_repo.dart';
import 'address_states.dart';

class AddressCubit extends Cubit<AddressState> with SafeEmitMixin<AddressState> {
  final AddressRepository _repository;
  bool _isGuest = false;
  void setGuestMode(bool value) => _isGuest = value;

  AddressCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(AddressInitial());

  Future<void> loadAddresses() async {
    if (_isGuest) return;
    final token = await SecureStorageService().getToken();
    if (token == null || token.isEmpty) return;
    safeEmit(AddressLoading());
    try {
      dLog('AddressCubit: Loading addresses');
      final response = await _repository.getAddresses();
      dLog('AddressCubit: Loaded ${response.addresses.length} addresses');
      if (!isClosed) {
        await _syncDefaultLocation(response.addresses);
        safeEmit(AddressesLoaded(response.addresses));
      }
    } catch (e) {
      dLog('AddressCubit: Error loading addresses: $e');
      if (!isClosed) {
        safeEmit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  /// Pushes the default address coordinates to [LocationService] so any
  /// data-source can include them in requests without a BuildContext.
  /// Also persists them to storage so the next cold start has them immediately.
  Future<void> _syncDefaultLocation(List<Address> addresses) async {
    if (addresses.isEmpty) {
      await LocationService.instance.update(lat: null, lng: null);
      return;
    }

    final defaultAddress = addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    );

    await LocationService.instance.update(
      lat: defaultAddress.addressLat.isNotEmpty ? defaultAddress.addressLat : null,
      lng: defaultAddress.addressLong.isNotEmpty ? defaultAddress.addressLong : null,
    );

    dLog('LocationService updated: lat=${defaultAddress.addressLat}, lng=${defaultAddress.addressLong}');
  }

  Future<void> createAddress(Address address) async {
    safeEmit(AddressLoading());
    try {
      dLog('AddressCubit: Creating address');
      final response = await _repository.createAddress(address);
      dLog('AddressCubit: Address created successfully');
      if (!isClosed) {
        safeEmit(
          AddressOperationSuccess(
            message: response.message,
            address: response.address,
          ),
        );
      }

      // Reload addresses
      await loadAddresses();
    } catch (e) {
      dLog('AddressCubit: Error creating address: $e');
      if (!isClosed) {
        safeEmit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> updateAddress(int addressId, Address address) async {
    safeEmit(AddressLoading());
    try {
      dLog('AddressCubit: Updating address $addressId');
      final response = await _repository.updateAddress(addressId, address);
      dLog('AddressCubit: Address updated successfully');
      if (!isClosed) {
        safeEmit(
          AddressOperationSuccess(
            message: response.message,
            address: response.address,
          ),
        );
      }

      // Reload addresses
      await loadAddresses();
    } catch (e) {
      dLog('AddressCubit: Error updating address: $e');
      if (!isClosed) {
        safeEmit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> deleteAddress(int addressId) async {
    safeEmit(AddressLoading());
    try {
      dLog('AddressCubit: Deleting address $addressId');
      await _repository.deleteAddress(addressId);
      dLog('AddressCubit: Address deleted successfully');
      if (!isClosed) {
        safeEmit(
          const AddressOperationSuccess(
            message: 'Address deleted successfully',
          ),
        );
      }

      // Reload addresses
      await loadAddresses();
    } catch (e) {
      dLog('AddressCubit: Error deleting address: $e');
      if (!isClosed) {
        safeEmit(AddressError(extractErrorMessage(e)));
      }
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
    try {
      dLog('AddressCubit: Creating address unavailable request');
      await _repository.createAddressUnAvailableRequest(
        isPickup,
        long,
        lat,
        address,
        area,
        governorate,
      );
      dLog('AddressCubit: Address unavailable request created successfully');
    } catch (e) {
      dLog('AddressCubit: Error creating address unavailable request: $e');
    }
  }
}
