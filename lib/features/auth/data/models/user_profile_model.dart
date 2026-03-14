class UserProfileModel {
  final int id;
  final String? email;
  final String fullName;
  final String? phone;
  final String? personalPhoto;
  final String? gender;
  final String? lang;
  final bool? isActive;
  final DateTime? deletedAt;
  final RoleModel? role;

  UserProfileModel({
    required this.id,
    this.email,
    required this.fullName,
    this.phone,
    this.personalPhoto,
    this.gender,
    this.lang,
    this.isActive,
    this.deletedAt,
    this.role,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json;

    return UserProfileModel(
      id: user['id'] as int,
      email: user['email'] as String?,
      fullName: user['full_name'] as String,
      phone: user['phone'] as String?,
      personalPhoto: user['personal_photo'] as String?,
      gender: user['gender'] as String?,
      lang: user['lang'] as String?,
      isActive: user['is_active'] as bool?,
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
      "email": email,
      "full_name": fullName,
      "phone": phone,
      "personal_photo": personalPhoto,
      "gender": gender,
      "lang": lang,
      "is_active": isActive,
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