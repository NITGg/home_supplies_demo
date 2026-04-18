class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? nameAr;
  final String? description;
  final String? descriptionAr;
  final String? imageUrl;
  final String? iconUrl;
  final int? parentId;
  final bool isActive;
  final Map<String, dynamic>? productAttributes;
  final String? synonyms;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int sortId;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.nameAr,
    this.description,
    this.descriptionAr,
    this.imageUrl,
    this.iconUrl,
    this.parentId,
    required this.isActive,
    this.productAttributes,
    this.synonyms,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.sortId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      nameAr: json['name_ar'] as String?,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      imageUrl: json['image_url'] as String?,
      iconUrl: json['icon_url'] as String?,
      parentId: json['parent_id'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      productAttributes: json['product_attributes'] as Map<String, dynamic>?,
      synonyms: json['synonyms']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      sortId: json['sort_id'] as int? ?? 0,
    );
  }

  bool get isRoot => parentId == null;

  String get displayName => nameAr ?? name;

  String get displayDescription => descriptionAr ?? description ?? '';
}
