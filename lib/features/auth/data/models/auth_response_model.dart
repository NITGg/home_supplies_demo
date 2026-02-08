// auth_response_model.dart

class AuthResponseModel {
  // final int status;
  final String message;
  final AuthData data;

  AuthResponseModel({
    // required this.status,
    required this.message,
    required this.data,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      // status: json['status'] as int,
      message: json['message'] as String,
      data: AuthData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class AuthData {
  final String accessToken;
  final String refreshToken;

  AuthData({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}


// OTP Verification Response
class OtpVerificationResponse {
  final String message;
  final Map<String, dynamic> data;

  OtpVerificationResponse({
    required this.message,
    required this.data,
  });

  factory OtpVerificationResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResponse(
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

// Refresh Token Response
class RefreshTokenResponse {
  final int status;
  final String message;
  final RefreshTokenData data;

  RefreshTokenResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      status: json['status'] as int,
      message: json['message'] as String,
      data: RefreshTokenData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class RefreshTokenData {
  final String accessToken;

  RefreshTokenData({required this.accessToken});

  factory RefreshTokenData.fromJson(Map<String, dynamic> json) {
    return RefreshTokenData(
      accessToken: json['accessToken'] as String,
    );
  }
}

// Forgot Password Response
class ForgotPasswordResponse {
  final int status;
  final String message;
  final Map<String, dynamic> data;

  ForgotPasswordResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      status: json['status'] as int,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

// Reset Password Response
class ResetPasswordResponse {
  final int status;
  final String message;
  final Map<String, dynamic> data;

  ResetPasswordResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      status: json['status'] as int,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}