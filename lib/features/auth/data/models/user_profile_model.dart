// profile_model.dart

import 'package:tawreedat_courier/features/auth/data/models/vehicles_model.dart';

class ProfileResponseModel {
  final String message;
  final ProfileData data;

  ProfileResponseModel({required this.message, required this.data});

  factory ProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return ProfileResponseModel(
      message: json['message'] as String,
      data: ProfileData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class ProfileData {
  final UserProfileModel user;

  ProfileData({required this.user});

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      user: UserProfileModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserProfileModel {
  final int id;
  final int roleId;
  final int badgeId;
  final String fullName;
  final String? email;
  final String phone;
  final String? extraPhones;
  final String? personalPhoto;
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
  final CourierModel courier;

  UserProfileModel({
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
    required this.courier,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as int,
      roleId: json['role_id'] as int,
      badgeId: json['badge_id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      extraPhones: json['extra_phones'] as String?,
      personalPhoto: json['personal_photo'] as String?,
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
      courier: CourierModel.fromJson(json['courier'] as Map<String, dynamic>),
    );
  }
}

class BadgeModel {
  final int id;
  final int roleId;
  final String name;
  final String nameAr;
  final String image;
  final String description;
  final String descriptionAr;
  final int minCount;
  final int maxCount;
  final int ratio;
  final DateTime createdAt;
  final DateTime updatedAt;

  BadgeModel({
    required this.id,
    required this.roleId,
    required this.name,
    required this.nameAr,
    required this.image,
    required this.description,
    required this.descriptionAr,
    required this.minCount,
    required this.maxCount,
    required this.ratio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as int,
      roleId: json['role_id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      image: json['image'] as String,
      description: json['description'] as String,
      descriptionAr: json['description_ar'] as String,
      minCount: json['min_count'] as int,
      maxCount: json['max_count'] as int,
      ratio: json['ratio'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}


class CourierModel {
  final int id;
  final int userId;
  final bool isApproved;
  final String? vehiclePlate;
  final VehicleModel? vehicleType;

  // ── Documents: each has a front and back side ────────────────────────────
  final String? nationalIdPhotoFront;
  final String? nationalIdPhotoBack;
  final String? vehicleLicenseFront;
  final String? vehicleLicenseBack;
  final String? courierLicenseFront;
  final String? courierLicenseBack;
  final String? criminalRecord;

  const CourierModel({
    required this.id,
    required this.userId,
    required this.isApproved,
    this.vehiclePlate,
    this.vehicleType,
    this.nationalIdPhotoFront,
    this.nationalIdPhotoBack,
    this.vehicleLicenseFront,
    this.vehicleLicenseBack,
    this.courierLicenseFront,
    this.courierLicenseBack,
    this.criminalRecord,
  });

  factory CourierModel.fromJson(Map<String, dynamic> json) {
    return CourierModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      isApproved: json['is_approved'] as bool? ?? false,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleType: json['vehicle'] != null
          ? VehicleModel.fromJson(json['vehicle'] as Map<String, dynamic>)
          : null,
      nationalIdPhotoFront: json['national_id_photo_front'] as String?,
      nationalIdPhotoBack: json['national_id_photo_back'] as String?,
      vehicleLicenseFront: json['vehicle_license_front'] as String?,
      vehicleLicenseBack: json['vehicle_license_back'] as String?,
      courierLicenseFront: json['courier_license_front'] as String?,
      courierLicenseBack: json['courier_license_back'] as String?,
      criminalRecord: json['courier_criminal_record'] as String?,
    );
  }
}

// Badge Progress Models
class BadgeProgressResponseModel {
  final String message;
  final BadgeProgressData data;

  BadgeProgressResponseModel({required this.message, required this.data});

  factory BadgeProgressResponseModel.fromJson(Map<String, dynamic> json) {
    return BadgeProgressResponseModel(
      message: json['message'] as String,
      data: BadgeProgressData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class BadgeProgressData {
  final BadgeModel currentBadge;
  final List<BadgeModel> allBadges;

  BadgeProgressData({required this.currentBadge, required this.allBadges});

  factory BadgeProgressData.fromJson(Map<String, dynamic> json) {
    return BadgeProgressData(
      currentBadge: BadgeModel.fromJson(
        json['current_badge'] as Map<String, dynamic>,
      ),
      allBadges: (json['all_badges'] as List)
          .map((badge) => BadgeModel.fromJson(badge as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Update Profile Response
class UpdateProfileResponseModel {
  final String message;
  final Map<String, dynamic> data;

  UpdateProfileResponseModel({required this.message, required this.data});

  factory UpdateProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return UpdateProfileResponseModel(
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

enum DocumentType {
  nationalId,
  vehicleLicense,
  courierLicense,
  personalPhoto,
  criminalRecord,
}
