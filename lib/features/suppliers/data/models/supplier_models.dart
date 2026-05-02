import 'package:tawreedat_go/l10n/manager/locale_cubit.dart';

/// Lightweight supplier user info embedded in every supplier response.
class SupplierUserModel {
  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final String? personalPhoto;

  const SupplierUserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.personalPhoto,
  });

  factory SupplierUserModel.fromJson(Map<String, dynamic> json) {
    return SupplierUserModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      personalPhoto: json['personal_photo'] as String?,
    );
  }
}

/// Minimal category info returned inside supplier responses.
class SupplierCategoryModel {
  final int id;
  final String name;
  final String? nameAr;
  final String? imageUrl;
  final String? iconUrl;

  const SupplierCategoryModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.imageUrl,
    this.iconUrl,
  });

  factory SupplierCategoryModel.fromJson(Map<String, dynamic> json) {
    return SupplierCategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      imageUrl: json['image_url'] as String?,
      iconUrl: json['icon_url'] as String?,
    );
  }

  /// Mirrors [CategoryModel.displayName] — returns Arabic name when the
  /// current locale is Arabic, falling back to the English name.
  String get displayName =>
      LocaleManager.currentLocale == 'ar' ? (nameAr ?? name) : name;
}

/// Core supplier model — covers both list and detail responses.
class SupplierModel {
  final int id;
  final bool isApproved;
  final String? synonyms;
  final SupplierUserModel user;

  // Detail-only fields (null when from list response)
  final List<SupplierCategoryModel> categories;

  const SupplierModel({
    required this.id,
    required this.isApproved,
    this.synonyms,
    required this.user,
    this.categories = const [],
  });

  /// Parses the flat supplier object from list endpoints.
  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    // The detail endpoint wraps categories as [{category: {...}}]
    final rawCats = json['categories'] as List<dynamic>? ?? [];
    final categories = rawCats.map((e) {
      final inner = e as Map<String, dynamic>;
      // List endpoint: {id, name, ...}  →  use directly
      // Detail endpoint: {category: {id, name, ...}}  →  unwrap
      final catJson = inner.containsKey('category')
          ? inner['category'] as Map<String, dynamic>
          : inner;
      return SupplierCategoryModel.fromJson(catJson);
    }).toList();

    return SupplierModel(
      id: json['id'] as int,
      isApproved: json['is_approved'] as bool? ?? false,
      synonyms: json['synonyms'] as String?,
      user: SupplierUserModel.fromJson(
          json['user'] as Map<String, dynamic>),
      categories: categories,
    );
  }

  /// Display name: prefer synonyms first word, fall back to user full name.
  String get displayName {
    return user.fullName;
  }

  String? get photoUrl => user.personalPhoto;
}