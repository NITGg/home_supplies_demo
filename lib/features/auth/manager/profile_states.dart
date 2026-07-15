import 'package:equatable/equatable.dart';
import '../data/models/user_profile_model.dart';
import '../data/models/vehicles_model.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final UserProfileModel profile;
  const ProfileLoaded({required this.profile});

  @override
  List<Object?> get props => [profile];
}

class ProfileUpdateSuccess extends ProfileState {
  final String message;
  const ProfileUpdateSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class ProfileFailure extends ProfileState {
  final String message;
  const ProfileFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class VehiclesLoaded extends ProfileState {
  final List<VehicleModel> vehicles;
  const VehiclesLoaded({required this.vehicles});

  @override
  List<Object?> get props => [vehicles];
}

class VehiclesFailure extends ProfileState {
  final String message;
  const VehiclesFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class ProfileChangePhoneOtpSent extends ProfileState {
  final String newPhone;
  final String? oldPhone;
  const ProfileChangePhoneOtpSent({required this.newPhone, this.oldPhone});

  @override
  List<Object?> get props => [newPhone, oldPhone];
}

class ProfileChangePhoneSuccess extends ProfileState {
  final String message;
  const ProfileChangePhoneSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class ProfileChangePhoneOtpResent extends ProfileState {
  final String message;
  const ProfileChangePhoneOtpResent({required this.message});

  @override
  List<Object?> get props => [message];
}
