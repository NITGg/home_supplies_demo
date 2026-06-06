class UserProfileModel {
  final int id;
  final int? roleId;
  final int? badgeId;
  final String? email;
  final String fullName;
  final String? phone;
  final String? extraPhones;
  final String? personalPhoto;
  final String? gender;
  final String? lang;
  final String? referralCode;
  final bool? isActive;
  final bool? isEmailVerified;
  final bool? isPhoneVerified;
  final String? fcmToken;
  final String? loginType;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final RoleModel? role;

  UserProfileModel({
    required this.id,
    this.roleId,
    this.badgeId,
    this.email,
    required this.fullName,
    this.phone,
    this.extraPhones,
    this.personalPhoto,
    this.gender,
    this.referralCode,
    this.lang,
    this.isActive,
    this.isEmailVerified,
    this.isPhoneVerified,
    this.fcmToken,
    this.loginType,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.role,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json;

    return UserProfileModel(
      id: user['id'] as int,
      roleId: user['role_id'] as int?,
      badgeId: user['badge_id'] as int?,
      email: user['email'] as String?,
      referralCode: user['referral_code'] as String?,
      fullName: user['full_name'] as String,
      phone: user['phone'] as String?,
      extraPhones: user['extra_phones'] as String?,
      personalPhoto: (user['personal_photo'] ?? user['image_url']) as String?,
      gender: user['gender'] as String?,
      lang: user['lang'] as String?,
      isActive: user['is_active'] as bool?,
      isEmailVerified: user['is_email_verified'] as bool?,
      isPhoneVerified: user['is_phone_verified'] as bool?,
      fcmToken: user['fcm_token'] as String?,
      loginType: user['login_type'] as String?,
      lastLoginAt: user['last_login_at'] != null
          ? DateTime.tryParse(user['last_login_at'])
          : null,
      createdAt: user['created_at'] != null
          ? DateTime.tryParse(user['created_at'])
          : null,
      updatedAt: user['updated_at'] != null
          ? DateTime.tryParse(user['updated_at'])
          : null,
      deletedAt: user['deleted_at'] != null
          ? DateTime.tryParse(user['deleted_at'])
          : null,
      role: user['role'] != null && user['role'] is Map<String, dynamic>
          ? RoleModel.fromJson(user['role'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "role_id": roleId,
      "badge_id": badgeId,
      "email": email,
      "full_name": fullName,
      "phone": phone,
      "extra_phones": extraPhones,
      "personal_photo": personalPhoto,
      "gender": gender,
      "lang": lang,
      "is_active": isActive,
      "is_email_verified": isEmailVerified,
      "is_phone_verified": isPhoneVerified,
      "fcm_token": fcmToken,
      "login_type": loginType,
      "last_login_at": lastLoginAt?.toIso8601String(),
      "created_at": createdAt?.toIso8601String(),
      "updated_at": updatedAt?.toIso8601String(),
      "deleted_at": deletedAt?.toIso8601String(),
      "role": role?.toJson(),
    };
  }
}


class RoleModel {
  final String name;

  RoleModel({required this.name});

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
    };
  }
}

class ProfileResponseModel {
  final UserProfileModel user;

  ProfileResponseModel({
    required this.user,
  });

  factory ProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return ProfileResponseModel(
      user: UserProfileModel.fromJson(
        json['user'] as Map<String, dynamic>,
      ),
    );
  }
}

class UpdateProfileResponseModel {
  final String message;
  final UserProfileModel user;

  UpdateProfileResponseModel({
    required this.message,
    required this.user,
  });

  factory UpdateProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return UpdateProfileResponseModel(
      message: json['message'] as String,
      user: UserProfileModel.fromJson(
        json['user'] as Map<String, dynamic>,
      ),
    );
  }
}

class DeleteProfileResponseModel {
  final String message;

  DeleteProfileResponseModel({required this.message});

  factory DeleteProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return DeleteProfileResponseModel(
      message: json['message'] as String,
    );
  }
}