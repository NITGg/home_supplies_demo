// auth_response_model.dart

class AuthResponseModel {
  final int status;
  final String message;
  final AuthData data;

  AuthResponseModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      status: json['status'] as int,
      message: json['message'] as String,
      data: AuthData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class AuthData {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  AuthData({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserModel {
  final int id;
  final int roleId;
  final int badgeId;
  final String fullName;
  final String? email;
  final String phone;
  final String? extraPhones;
  final String personalPhoto;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isActive;
  final String? fcmToken;
  final String lang;
  final String? googleId;
  final String? appleId;
  final String? lastLoginAt;
  final String loginType;
  final String? passwordLastUpdated;
  final String gender;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final CourierModel? courier;

  UserModel({
    required this.id,
    required this.roleId,
    required this.badgeId,
    required this.fullName,
    this.email,
    required this.phone,
    this.extraPhones,
    required this.personalPhoto,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.isActive,
    this.fcmToken,
    required this.lang,
    this.googleId,
    this.appleId,
    this.lastLoginAt,
    required this.loginType,
    this.passwordLastUpdated,
    required this.gender,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.courier,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      roleId: json['role_id'] as int,
      badgeId: json['badge_id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      extraPhones: json['extra_phones'] as String?,
      personalPhoto: json['personal_photo'] as String,
      isEmailVerified: json['is_email_verified'] as bool,
      isPhoneVerified: json['is_phone_verified'] as bool,
      isActive: json['is_active'] as bool,
      fcmToken: json['fcm_token'] as String?,
      lang: json['lang'] as String,
      googleId: json['google_id'] as String?,
      appleId: json['apple_id'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
      loginType: json['login_type'] as String,
      passwordLastUpdated: json['password_last_updated'] as String?,
      gender: json['gender'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      courier: json['courier'] != null
          ? CourierModel.fromJson(json['courier'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_id': roleId,
      'badge_id': badgeId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'extra_phones': extraPhones,
      'personal_photo': personalPhoto,
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
      'is_active': isActive,
      'fcm_token': fcmToken,
      'lang': lang,
      'google_id': googleId,
      'apple_id': appleId,
      'last_login_at': lastLoginAt,
      'login_type': loginType,
      'password_last_updated': passwordLastUpdated,
      'gender': gender,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'courier': courier?.toJson(),
    };
  }
}

class CourierModel {
  final int id;
  final int userId;
  final String nationalIdPhoto;
  final String vehicleType;
  final String vehiclePlate;
  final String? vehicleLicense;
  final String? courierLicense;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  CourierModel({
    required this.id,
    required this.userId,
    required this.nationalIdPhoto,
    required this.vehicleType,
    required this.vehiclePlate,
    this.vehicleLicense,
    this.courierLicense,
    required this.isApproved,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory CourierModel.fromJson(Map<String, dynamic> json) {
    return CourierModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      nationalIdPhoto: json['national_id_photo'] as String,
      vehicleType: json['vehicle_type'] as String,
      vehiclePlate: json['vehicle_plate'] as String,
      vehicleLicense: json['vehicle_license'] as String?,
      courierLicense: json['courier_license'] as String?,
      isApproved: json['is_approved'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'national_id_photo': nationalIdPhoto,
      'vehicle_type': vehicleType,
      'vehicle_plate': vehiclePlate,
      'vehicle_license': vehicleLicense,
      'courier_license': courierLicense,
      'is_approved': isApproved,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}

// OTP Verification Response
class OtpVerificationResponse {
  final int status;
  final String message;
  final Map<String, dynamic> data;

  OtpVerificationResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory OtpVerificationResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResponse(
      status: json['status'] as int,
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

// Add to auth_response_model.dart

class SocialAuthPhoneRequiredResponse {
  final int status;
  final String message;
  final bool requiresPhone;
  final String? idToken;

  SocialAuthPhoneRequiredResponse({
    required this.status,
    required this.message,
    required this.requiresPhone,
    this.idToken,
  });

  factory SocialAuthPhoneRequiredResponse.fromJson(Map<String, dynamic> json) {
    return SocialAuthPhoneRequiredResponse(
      status: json['status'] as int,
      message: json['message'] as String,
      requiresPhone: json['requiresPhone'] as bool? ?? false,
      idToken: json['idToken'] as String?,
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