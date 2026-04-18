
class ProductAttributeModel {
  final int id;
  final String key;
  final String value;
  final int productId;
  final String? valueAr;

  const ProductAttributeModel({
    required this.id,
    required this.key,
    required this.value,
    required this.productId,
    this.valueAr,
  });

  factory ProductAttributeModel.fromJson(Map<String, dynamic> json) {
    return ProductAttributeModel(
      id: json['id'] as int,
      key: json['key'] as String,
      value: json['value'] as String,
      productId: json['product_id'] as int,
      valueAr: json['value_ar'] as String?,
    );
  }

  String get displayValue => valueAr ?? value;
}