import 'product_attribute_model.dart';
import 'product_unit_model.dart';

class ProductModel {
  final int id;
  final String name;
  final String? nameAr;
  final String? description;
  final String? descriptionAr;
  final double price;
  final double? costPrice;
  final int stock;
  final int minStock;
  final String sku;
  final String? barcode;
  final List<String> images;
  final double? weight;
  final Map<String, dynamic>? dimensions;
  final bool isActive;
  final bool isFeatured;
  final double? offer;
  final int categoryId;
  final int? supplierId;
  final int? brandId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double rating;
  final int totalReviews;
  final DateTime? offerValidFrom;
  final DateTime? offerValidTo;
  final bool isBestSeller;
  final int sortId;
  final String? color;
  final DateTime? deletedAt;
  final String? discountType;
  final double? discountValueTotal;
  final double? priceOutSite;
  final String? refundPolicy;
  final bool? refundable;
  final int? refundablePeriod;
  final int? maxAmountForOneOrder;
  final int? minAmountForOneOrder;
  final String slug;
  final String? synonyms;
  final List<ProductAttributeModel> attributes;
  final List<ProductUnitModel> units;

  const ProductModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.description,
    this.descriptionAr,
    required this.price,
    this.costPrice,
    required this.stock,
    required this.minStock,
    required this.sku,
    this.barcode,
    required this.images,
    this.weight,
    this.dimensions,
    required this.isActive,
    required this.isFeatured,
    this.offer,
    required this.categoryId,
    this.supplierId,
    this.brandId,
    required this.createdAt,
    required this.updatedAt,
    required this.rating,
    required this.totalReviews,
    this.offerValidFrom,
    this.offerValidTo,
    required this.isBestSeller,
    required this.sortId,
    this.color,
    this.deletedAt,
    this.discountType,
    this.discountValueTotal,
    this.priceOutSite,
    this.refundPolicy,
    this.refundable,
    this.refundablePeriod,
    this.maxAmountForOneOrder,
    this.minAmountForOneOrder,
    required this.slug,
    this.synonyms,
    required this.attributes,
    required this.units,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String?,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      stock: json['stock'] as int? ?? 0,
      minStock: json['min_stock'] as int? ?? 0,
      sku: json['sku'] as String? ?? '',
      barcode: json['barcode'] as String?,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      weight: (json['weight'] as num?)?.toDouble(),
      dimensions: json['dimensions'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      offer: (json['offer'] as num?)?.toDouble(),
      categoryId: json['category_id'] as int,
      supplierId: json['supplier_id'] as int?,
      brandId: json['brand_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      offerValidFrom: json['offer_valid_from'] != null
          ? DateTime.tryParse(json['offer_valid_from'] as String)
          : null,
      offerValidTo: json['offer_valid_to'] != null
          ? DateTime.tryParse(json['offer_valid_to'] as String)
          : null,
      isBestSeller: json['is_best_seller'] as bool? ?? false,
      sortId: json['sort_id'] as int? ?? 0,
      color: json['color'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      discountType: json['discount_type'] as String?,
      discountValueTotal: (json['discount_value_total'] as num?)?.toDouble(),
      priceOutSite: (json['price_out_site'] as num?)?.toDouble(),
      refundPolicy: json['refund_policy'] as String?,
      refundable: json['refundable'] as bool?,
      refundablePeriod: json['refundable_period'] as int?,
      maxAmountForOneOrder: json['max_amount_for_one_order'] as int?,
      minAmountForOneOrder: json['min_amount_for_one_order'] as int?,
      slug: json['slug'] as String? ?? '',
      synonyms: json['synonyms'] as String?,
      attributes: (json['attributes'] as List<dynamic>?)
          ?.map((e) =>
          ProductAttributeModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      units: (json['units'] as List<dynamic>?)
          ?.map((e) =>
          ProductUnitModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  String get displayName => nameAr ?? name;
  String get displayDescription => descriptionAr ?? description ?? '';
  bool get hasOffer => offer != null && offer! > 0;
  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= minStock;
  String? get primaryImage => images.isNotEmpty ? images.first : null;

  double get effectivePrice {
    if (hasOffer) return offer!;
    return price;
  }
}