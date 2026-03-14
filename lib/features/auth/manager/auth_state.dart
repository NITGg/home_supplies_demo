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

// Keep for future OTP implementation
class AuthOtpRequired extends AuthState {
  final String phone;
  final ShortAuthResponseModel authResponse;

  AuthOtpRequired({required this.phone, required this.authResponse});
}

class AuthOtpResent extends AuthState {
  final String message;

  AuthOtpResent({required this.message});
}