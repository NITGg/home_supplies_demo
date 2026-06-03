import '../data/models/auth_response_model.dart';
import '../data/models/user_profile_model.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoggedIn extends AuthState {}

class AuthLoggedOut extends AuthState {}

class AuthLoading extends AuthState {}

class AuthRoleNotAllowed extends AuthState {
  final String message;
  AuthRoleNotAllowed(this.message);
}

class AuthSuccess extends AuthState {
  final ShortAuthResponseModel? shortAuthResponse;
  final LongAuthResponseModel? longAuthResponse;

  AuthSuccess({this.shortAuthResponse, this.longAuthResponse});
}

class AuthUpdateSuccess extends AuthState {
  final UserProfileModel? updatedUser;
  AuthUpdateSuccess({this.updatedUser});
}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

class AuthProfileDeleted extends AuthState {
  final String message;
  AuthProfileDeleted(this.message);
}

/// Emitted after registration — OTP has been sent to [destination].
/// [via] is "phone" or "email".
class AuthOtpRequired extends AuthState {
  final String destination; // phone or email to show on OTP screen
  final String via;         // "phone" or "email"
  AuthOtpRequired({required this.destination, required this.via});
}

/// Emitted when one channel is verified but another remains (e.g. email done, phone pending).
class AuthNextOtpRequired extends AuthState {
  final String destination; // next channel destination
  final String via;         // "phone" or "email"
  AuthNextOtpRequired({required this.destination, required this.via});
}

class AuthOtpResent extends AuthState {
  final String message;
  AuthOtpResent({required this.message});
}

class AuthForgotPasswordOtpSent extends AuthState {
  /// Phone number OR email — whatever the user entered.
  final String destination;
  final String message;
  AuthForgotPasswordOtpSent({required this.destination, required this.message});
}