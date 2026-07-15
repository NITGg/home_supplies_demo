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
  final bool verfied;

  AuthData({
    required this.verfied,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      verfied: json['user']['isPhoneVerified'] == true,
    );
  }

  factory AuthData.fromTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    return AuthData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      verfied: true,
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

// ── New multi-channel OTP / password-reset models (not yet wired) ──────────

// Response for POST /auth/verify-account
class VerifyAccountResponse {
  final String message;
  final bool fullyVerified;
  final List<String> unverified;

  VerifyAccountResponse({
    required this.message,
    required this.fullyVerified,
    required this.unverified,
  });

  factory VerifyAccountResponse.fromJson(Map<String, dynamic> json) {
    return VerifyAccountResponse(
      message: json['message'] as String,
      fullyVerified: json['fullyVerified'] == true,
      unverified: (json['unverified'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

// Response for POST /auth/request-verification
class RequestVerificationResponse {
  final String message;

  RequestVerificationResponse({required this.message});

  factory RequestVerificationResponse.fromJson(Map<String, dynamic> json) {
    return RequestVerificationResponse(
      message: json['message'] as String,
    );
  }
}

// Response for POST /auth/forget-password (multi-channel: {identifier, channel})
class ForgetPasswordChannelResponse {
  final String message;
  final String destination;
  final String via;

  ForgetPasswordChannelResponse({
    required this.message,
    required this.destination,
    required this.via,
  });

  factory ForgetPasswordChannelResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return ForgetPasswordChannelResponse(
      message: json['message'] as String,
      destination: data['destination'] as String? ?? '',
      via: data['via'] as String? ?? '',
    );
  }
}

// Response for POST /auth/verify-forget-password
class VerifyForgetPasswordResponse {
  final String message;

  VerifyForgetPasswordResponse({required this.message});

  factory VerifyForgetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return VerifyForgetPasswordResponse(
      message: json['message'] as String,
    );
  }
}

// Response for POST /auth/verify-otp and /auth/resend-otp
class VerifyOtpResponse {
  final String message;
  final String? accessToken;
  final String? refreshToken;

  VerifyOtpResponse({
    required this.message,
    this.accessToken,
    this.refreshToken,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return VerifyOtpResponse(
      message: json['message'] as String? ?? '',
      accessToken: data['accessToken'] as String?,
      refreshToken: data['refreshToken'] as String?,
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