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

class ProfileChangePhoneSuccess extends ProfileState {
  final String message;

  ProfileChangePhoneSuccess({required this.message});
}

class ProfileChangeEmailSuccess extends ProfileState {
  final String message;

  ProfileChangeEmailSuccess({required this.message});
}
class ProfileOtpConfirmSuccess extends ProfileState {
  final String message;
  ProfileOtpConfirmSuccess({required this.message});
}

/// Emitted after POST /profile/change-phone succeeds.
/// The OTP screen should be pushed with [destination] and [via].
class ProfilePhoneOtpSent extends ProfileState {
  final String destination; // the new phone number
  final String via;         // "phone" (always for this flow)
  final String message;
  ProfilePhoneOtpSent({
    required this.destination,
    required this.message,
    this.via = 'phone',
  });
}