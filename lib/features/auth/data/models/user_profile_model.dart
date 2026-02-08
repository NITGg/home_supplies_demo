// profile_model.dart

class ProfileResponseModel {
  final String message;
  final ProfileData data;

  ProfileResponseModel({
    required this.message,
    required this.data,
  });

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
  final String nationalIdPhoto;
  final String vehicleType;
  final String vehiclePlate;
  final String? vehicleLicense;
  final String? courierLicense;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final CourierStatsModel stat;

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
    required this.stat,
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
      stat: CourierStatsModel.fromJson(json['stat'] as Map<String, dynamic>),
    );
  }
}

class CourierStatsModel {
  final int id;
  final int courierId;
  final int totalCompletedOrders;
  final int totalCancelledOrders;
  final String totalEarnings;
  final String averageRating;
  final int totalReviews;
  final String acceptanceRate;
  final String completionRate;
  final int avgDeliveryTime;
  final DateTime updatedAt;

  CourierStatsModel({
    required this.id,
    required this.courierId,
    required this.totalCompletedOrders,
    required this.totalCancelledOrders,
    required this.totalEarnings,
    required this.averageRating,
    required this.totalReviews,
    required this.acceptanceRate,
    required this.completionRate,
    required this.avgDeliveryTime,
    required this.updatedAt,
  });

  factory CourierStatsModel.fromJson(Map<String, dynamic> json) {
    return CourierStatsModel(
      id: json['id'] as int,
      courierId: json['courier_id'] as int,
      totalCompletedOrders: json['total_completed_orders'] as int,
      totalCancelledOrders: json['total_cancelled_orders'] as int,
      totalEarnings: json['total_earnings'] as String,
      averageRating: json['average_rating'] as String,
      totalReviews: json['total_reviews'] as int,
      acceptanceRate: json['acceptance_rate'] as String,
      completionRate: json['completion_rate'] as String,
      avgDeliveryTime: json['avg_delivery_time'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

// Badge Progress Models
class BadgeProgressResponseModel {
  final String message;
  final BadgeProgressData data;

  BadgeProgressResponseModel({
    required this.message,
    required this.data,
  });

  factory BadgeProgressResponseModel.fromJson(Map<String, dynamic> json) {
    return BadgeProgressResponseModel(
      message: json['message'] as String,
      data: BadgeProgressData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class BadgeProgressData {
  final BadgeModel currentBadge;
  final CourierStatsModel stats;

  BadgeProgressData({
    required this.currentBadge,
    required this.stats,
  });

  factory BadgeProgressData.fromJson(Map<String, dynamic> json) {
    return BadgeProgressData(
      currentBadge: BadgeModel.fromJson(json['current_badge'] as Map<String, dynamic>),
      stats: CourierStatsModel.fromJson(json['stats'] as Map<String, dynamic>),
    );
  }
}

// Update Profile Response
class UpdateProfileResponseModel {
  final String message;
  final Map<String, dynamic> data;

  UpdateProfileResponseModel({
    required this.message,
    required this.data,
  });

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
}
