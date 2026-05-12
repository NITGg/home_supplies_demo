import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
import '../../../core/utils/logger.dart';
import '../data/models/address_model.dart';
import '../data/repo/address_repo.dart';
import 'address_states.dart';

class AddressCubit extends Cubit<AddressState> {
  final AddressRepository _repository;

  AddressCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(AddressInitial());

  Future<void> loadAddresses() async {
    emit(AddressLoading());
    try {
      dLog('AddressCubit: Loading addresses');
      final response = await _repository.getAddresses();
      dLog('AddressCubit: Loaded ${response.addresses.length} addresses');
      if (!isClosed) {
        emit(AddressesLoaded(response.addresses));
      }
    } catch (e) {
      dLog('AddressCubit: Error loading addresses: $e');
      if (!isClosed) {
        emit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> createAddress(Address address) async {
    emit(AddressLoading());
    try {
      dLog('AddressCubit: Creating address');
      final response = await _repository.createAddress(address);
      dLog('AddressCubit: Address created successfully');
      if (!isClosed) {
        emit(
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
        emit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> updateAddress(int addressId, Address address) async {
    emit(AddressLoading());
    try {
      dLog('AddressCubit: Updating address $addressId');
      final response = await _repository.updateAddress(addressId, address);
      dLog('AddressCubit: Address updated successfully');
      if (!isClosed) {
        emit(
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
        emit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> deleteAddress(int addressId) async {
    emit(AddressLoading());
    try {
      dLog('AddressCubit: Deleting address $addressId');
      await _repository.deleteAddress(addressId);
      dLog('AddressCubit: Address deleted successfully');
      if (!isClosed) {
        emit(
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
        emit(AddressError(extractErrorMessage(e)));
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
