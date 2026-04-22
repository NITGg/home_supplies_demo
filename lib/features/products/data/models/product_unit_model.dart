class ProductUnitModel {
  final int id;
  final String name;
  final double price;
  final String? description;
  final String? descriptionAr;
  final String? nameAr;
  final int productId;

  const ProductUnitModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.descriptionAr,
    this.nameAr,
    required this.productId,
  });

  factory ProductUnitModel.fromJson(Map<String, dynamic> json) {
    return ProductUnitModel(
      id: json['id'] as int,
      name: json['name'] as String,
      // Backend sends monetary values in cents → divide by 100 to get EGP.
      price: (double.tryParse(json['price']?.toString() ?? '0') ?? 0.0) / 100.0,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      nameAr: json['name_ar'] as String?,
      productId: json['product_id'] as int,
    );
  }

  String get displayName => nameAr ?? name;
}