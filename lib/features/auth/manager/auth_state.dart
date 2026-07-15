import 'package:equatable/equatable.dart';
import '../data/models/auth_response_model.dart';
import '../data/models/social_registration_data.dart';
import '../data/models/user_profile_model.dart';
import '../data/models/vehicles_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoggedIn extends AuthState {
  const AuthLoggedIn();
}

class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSuccess extends AuthState {
  final String message;

  const AuthSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthSocialLinkSuccess extends AuthState {
  final String message;

  const AuthSocialLinkSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthOtpRequired extends AuthState {
  final String phone;
  final AuthResponseModel? authResponse;

  const AuthOtpRequired({required this.phone, this.authResponse});

  @override
  List<Object?> get props => [phone, authResponse];
}

class AuthOtpResent extends AuthState {
  final String message;

  const AuthOtpResent({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthUpdateSuccess extends AuthState {
  final UserProfileModel? user;

  const AuthUpdateSuccess({this.user});

  @override
  List<Object?> get props => [user];
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthProfileDeleted extends AuthState {
  final Map<String, dynamic> response;

  const AuthProfileDeleted(this.response);

  @override
  List<Object?> get props => [response];
}

// States for forgot password flow
class AuthForgotPasswordOtpSent extends AuthState {
  final String message;
  final String phone;

  const AuthForgotPasswordOtpSent({required this.message, required this.phone});

  @override
  List<Object?> get props => [message, phone];
}

class AuthPasswordResetSuccess extends AuthState {
  final String message;

  const AuthPasswordResetSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

// States for available vehicles
class AuthVehiclesLoaded extends AuthState {
  final List<VehicleModel> vehicles;

  const AuthVehiclesLoaded({required this.vehicles});

  @override
  List<Object?> get props => [vehicles];
}

class AuthVehiclesFailure extends AuthState {
  final String message;

  const AuthVehiclesFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// ── New multi-channel OTP / password-reset states (not yet wired) ──────────

class AuthAccountVerified extends AuthState {
  final String message;

  const AuthAccountVerified({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthNextOtpRequired extends AuthState {
  final String destination;
  final String via;

  const AuthNextOtpRequired({required this.destination, required this.via});

  @override
  List<Object?> get props => [destination, via];
}

class AuthVerificationCodeResent extends AuthState {
  final String message;

  const AuthVerificationCodeResent({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthForgotPasswordChannelOtpSent extends AuthState {
  final String message;
  final String destination;
  final String via;

  const AuthForgotPasswordChannelOtpSent({
    required this.message,
    required this.destination,
    required this.via,
  });

  @override
  List<Object?> get props => [message, destination, via];
}

class AuthSocialRegistrationRequired extends AuthState {
  final SocialRegistrationData socialData;
  const AuthSocialRegistrationRequired(this.socialData);

  @override
  List<Object?> get props => [socialData];
}
