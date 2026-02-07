class UserProfileModel {
  final String id;
  final String? email;
  final String fullname;
  final String? phone;
  final String? imageUrl;
  final String? lang;
  final bool? isActive;
  final bool? isConfirmed;
  final String? birthDate;
  final String? gender;
  final String? role;
  final String? loginType;

  UserProfileModel({
    required this.id,
    this.email,
    required this.fullname,
    required this.phone,
    this.imageUrl,
    this.lang,
    this.isActive,
    this.isConfirmed,
    this.birthDate,
    this.gender,
    this.role,
    this.loginType,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json; // handle both {user:{...}} or {...}
    return UserProfileModel(
      id: user['id'],
      email: user['email'],
      fullname: user['full_name'],
      phone: user['phone'],
      imageUrl: user['image_url'],
      lang: user['lang'],
      isActive: user['is_Active'],
      isConfirmed: user['is_confirmed'],
      birthDate: user['birth_date'],
      gender: user['gender'],
      role: user['role'],
      loginType: user['login_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "full_name": fullname,
      "phone": phone,
      "image_url": imageUrl,
      "lang": lang,
      "is_Active": isActive,
      "is_confirmed": isConfirmed,
      "birth_date": birthDate,
      "gender": gender,
      "role": role,
      "login_type": loginType,
    };
  }
}
