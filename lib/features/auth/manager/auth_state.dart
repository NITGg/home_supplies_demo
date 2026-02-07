// auth_state.dart
import '../data/models/auth_response_model.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoggedIn extends AuthState {}

class AuthLoggedOut extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String message;
  AuthSuccess({required this.message});
}

class AuthOtpRequired extends AuthState {
  final String phone;
  final AuthResponseModel authResponse;
  AuthOtpRequired({required this.phone, required this.authResponse});
}

class AuthOtpResent extends AuthState {
  final String message;
  AuthOtpResent({required this.message});
}

class AuthUpdateSuccess extends AuthState {
  final UserModel? user;
  AuthUpdateSuccess({this.user});
}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

class AuthProfileDeleted extends AuthState {
  final Map<String, dynamic> response;
  AuthProfileDeleted(this.response);
}

// States for forgot password flow
class AuthForgotPasswordOtpSent extends AuthState {
  final String message;
  final String phone;

  AuthForgotPasswordOtpSent({
    required this.message,
    required this.phone,
  });
}

class AuthPasswordResetSuccess extends AuthState {
  final String message;
  AuthPasswordResetSuccess({required this.message});
}