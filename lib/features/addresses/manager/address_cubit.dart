import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/extract_error_message.dart';
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
      log('AddressCubit: Loading addresses');
      final response = await _repository.getAddresses();
      log('AddressCubit: Loaded ${response.addresses.length} addresses');
      if (!isClosed) {
        emit(AddressesLoaded(response.addresses));
      }
    } catch (e) {
      log('AddressCubit: Error loading addresses: $e');
      if (!isClosed) {
        emit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> createAddress(Address address) async {
    emit(AddressLoading());
    try {
      log('AddressCubit: Creating address');
      final response = await _repository.createAddress(address);
      log('AddressCubit: Address created successfully');
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
      log('AddressCubit: Error creating address: $e');
      if (!isClosed) {
        emit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> updateAddress(int addressId, Address address) async {
    emit(AddressLoading());
    try {
      log('AddressCubit: Updating address $addressId');
      final response = await _repository.updateAddress(addressId, address);
      log('AddressCubit: Address updated successfully');
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
      log('AddressCubit: Error updating address: $e');
      if (!isClosed) {
        emit(AddressError(extractErrorMessage(e)));
      }
    }
  }

  Future<void> deleteAddress(int addressId) async {
    emit(AddressLoading());
    try {
      log('AddressCubit: Deleting address $addressId');
      await _repository.deleteAddress(addressId);
      log('AddressCubit: Address deleted successfully');
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
      log('AddressCubit: Error deleting address: $e');
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
      log('AddressCubit: Creating address unavailable request');
      await _repository.createAddressUnAvailableRequest(
        isPickup,
        long,
        lat,
        address,
        area,
        governorate,
      );
      log('AddressCubit: Address unavailable request created successfully');
    } catch (e) {
      log('AddressCubit: Error creating address unavailable request: $e');
    }
  }
}
