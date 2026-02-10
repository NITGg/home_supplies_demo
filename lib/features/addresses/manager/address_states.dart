

import '../data/models/address_model.dart';

abstract class AddressState{
  const AddressState();

  @override
  List<Object?> get props => [];
}

class AddressInitial extends AddressState {}

class AddressLoading extends AddressState {}

class AddressesLoaded extends AddressState {
  final List<Address> addresses;

  const AddressesLoaded(this.addresses);

  @override
  List<Object?> get props => [addresses];
}

class AddressOperationSuccess extends AddressState {
  final String message;
  final Address? address;

  const AddressOperationSuccess({
    required this.message,
    this.address,
  });

  @override
  List<Object?> get props => [message, address];
}

class AddressError extends AddressState {
  final String message;

  const AddressError(this.message);

  @override
  List<Object?> get props => [message];
}