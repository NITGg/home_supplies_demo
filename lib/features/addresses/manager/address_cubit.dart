import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/address_model.dart';
import '../data/repo/address_repo.dart';
import 'address_states.dart';

class AddressCubit extends Cubit<AddressState> {
  final AddressRepository _repository;

  AddressCubit({
    AddressRepository? repository,
  })  : _repository = repository ?? AddressRepository(),
        super(AddressInitial());

  Future<void> loadAddresses() async {
    emit(AddressLoading());
    try {
      log('AddressCubit: Loading addresses');
      final response = await _repository.getAddresses();
      log('AddressCubit: Loaded ${response.addresses.length} addresses');
      emit(AddressesLoaded(response.addresses));
    } catch (e) {
      log('AddressCubit: Error loading addresses: $e');
      emit(AddressError(e.toString()));
    }
  }

  Future<void> createAddress(Address address) async {
    emit(AddressLoading());
    try {
      log('AddressCubit: Creating address');
      final response = await _repository.createAddress(address);
      log('AddressCubit: Address created successfully');

      emit(AddressOperationSuccess(
        message: response.message,
        address: response.address,
      ));

      // Reload addresses
      await loadAddresses();
    } catch (e) {
      log('AddressCubit: Error creating address: $e');
      emit(AddressError(e.toString()));
    }
  }

  Future<void> updateAddress(
      int addressId,
      Address address,
      ) async {
    emit(AddressLoading());
    try {
      log('AddressCubit: Updating address $addressId');
      final response = await _repository.updateAddress(addressId, address);
      log('AddressCubit: Address updated successfully');

      emit(AddressOperationSuccess(
        message: response.message,
        address: response.address,
      ));

      // Reload addresses
      await loadAddresses();
    } catch (e) {
      log('AddressCubit: Error updating address: $e');
      emit(AddressError(e.toString()));
    }
  }

  Future<void> deleteAddress(int addressId) async {
    emit(AddressLoading());
    try {
      log('AddressCubit: Deleting address $addressId');
      await _repository.deleteAddress(addressId);
      log('AddressCubit: Address deleted successfully');

      emit(const AddressOperationSuccess(
        message: 'Address deleted successfully',
      ));

      // Reload addresses
      await loadAddresses();
    } catch (e) {
      log('AddressCubit: Error deleting address: $e');
      emit(AddressError(e.toString()));
    }
  }
}