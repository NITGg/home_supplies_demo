import '../data/models/user_profile_model.dart';

abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserProfileModel profile;

  ProfileLoaded({required this.profile});
}

class ProfileUpdateSuccess extends ProfileState {
  final String message;

  ProfileUpdateSuccess({required this.message});
}

class ProfileFailure extends ProfileState {
  final String message;

  ProfileFailure(this.message);
}

