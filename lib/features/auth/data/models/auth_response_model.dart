/// Response from POST /register — no token yet, just user info + via channel.
class RegisterResponseModel {
  final String message;
  final RegisterUserModel user;
  final String via; // "phone" or "email"

  RegisterResponseModel({
    required this.message,
    required this.user,
    required this.via,
  });

  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterResponseModel(
      message: json['message'] as String,
      user: RegisterUserModel.fromJson(json['user'] as Map<String, dynamic>),
      via: json['via'] as String? ?? 'phone',
    );
  }
}

class RegisterUserModel {
  final int id;
  final String fullName;
  final String? email;
  final String? phone;
  final bool? isActive;
  final bool? isEmailVerified;
  final bool? isPhoneVerified;

  RegisterUserModel({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.isActive,
    this.isEmailVerified,
    this.isPhoneVerified,
  });

  factory RegisterUserModel.fromJson(Map<String, dynamic> json) {
    return RegisterUserModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool?,
      isEmailVerified: json['is_email_verified'] as bool?,
      isPhoneVerified: json['is_phone_verified'] as bool?,
    );
  }
}

/// Response from POST /verify-account.
class VerifyAccountResponseModel {
  final String message;
  final bool verified;
  final String via;
  final bool fullyVerified;
  final String? token; // present only when fullyVerified == true
  final List<String> unverified; // channels still pending

  VerifyAccountResponseModel({
    required this.message,
    required this.verified,
    required this.via,
    required this.fullyVerified,
    this.token,
    this.unverified = const [],
  });

  factory VerifyAccountResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifyAccountResponseModel(
      message: json['message'] as String,
      verified: json['verified'] as bool? ?? false,
      via: json['via'] as String? ?? '',
      fullyVerified: json['fullyVerified'] as bool? ?? false,
      token: json['token'] as String?,
      unverified: (json['unverified'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],
    );
  }
}

class ShortAuthResponseModel {
  final String message;
  final String token;
  final AuthUserModel user;

  ShortAuthResponseModel({
    required this.message,
    required this.token,
    required this.user,
  });

  factory ShortAuthResponseModel.fromJson(Map<String, dynamic> json) {
    return ShortAuthResponseModel(
      message: json['message'] as String,
      token: json['token'] as String,
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthUserModel {
  final int id;
  final String fullName;
  final String? email;
  final String phone;
  final String? role;
  final bool? isActive;

  AuthUserModel({
    required this.id,
    required this.fullName,
    this.email,
    required this.phone,
    this.role,
    this.isActive,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      role: json['role'] as String?,
      isActive: json['is_active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
    };
  }
}

// Keep for Google/Apple sign-in (if they still use the old response format)
class LongAuthResponseModel {
  final String message;
  final String token;
  final LongUserModel user;

  LongAuthResponseModel({
    required this.message,
    required this.token,
    required this.user,
  });

  factory LongAuthResponseModel.fromJson(Map<String, dynamic> json) {
    return LongAuthResponseModel(
      message: json['message'] as String,
      token: json['token'] as String,
      user: LongUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class LongUserModel {
  final int id;
  final String? email;
  final String fullName;
  final String? phone;
  final String? imageUrl;
  final String? lang;
  final DateTime? lastLoginAt;
  final bool? isActive;
  final bool? isConfirmed;
  final DateTime? passwordLastUpdated;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  final DateTime? birthDate;
  final String? gender;
  final String? fcmToken;
  final String? role;
  final String? loginType;

  LongUserModel({
    required this.id,
    this.email,
    required this.fullName,
    this.phone,
    this.imageUrl,
    this.lang,
    this.lastLoginAt,
    this.isActive,
    this.isConfirmed,
    this.passwordLastUpdated,
    this.updatedAt,
    this.createdAt,
    this.deletedAt,
    this.birthDate,
    this.gender,
    this.fcmToken,
    this.role,
    this.loginType,
  });

  factory LongUserModel.fromJson(Map<String, dynamic> json) {
    return LongUserModel(
      id: json['id'] as int,
      email: json['email'] as String?,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      imageUrl: json['image_url'] as String?,
      lang: json['lang'] as String?,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
      isActive: json['is_Active'] as bool?,
      isConfirmed: json['is_confirmed'] as bool?,
      passwordLastUpdated: json['password_last_updated'] != null
          ? DateTime.parse(json['password_last_updated'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      gender: json['gender'] as String?,
      fcmToken: json['fcm_token'] as String?,
      role: json['role'] as String?,
      loginType: json['login_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'image_url': imageUrl,
      'personal_photo': imageUrl,
      'lang': lang,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'is_Active': isActive,
      'is_confirmed': isConfirmed,
      'password_last_updated': passwordLastUpdated?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'fcm_token': fcmToken,
      'role': role,
      'login_type': loginType,
    };
  }
}