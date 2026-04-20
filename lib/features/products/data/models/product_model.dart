import '../../../../l10n/manager/locale_cubit.dart';
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

  // ── Supplier-context fields ───────────────────────────────────────────────
  final int? spId;
  final int? maxAmountForOneUser;
  final int? minAmountForOneUser;
  final int? reservedInCartsAmount;
  final int? pickupReadyDuration;

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
    this.spId,
    this.maxAmountForOneUser,
    this.minAmountForOneUser,
    this.reservedInCartsAmount,
    this.pickupReadyDuration,
  });

  // ── Products list / detail API ────────────────────────────────────────────
  //
  // Response shape:
  // {
  //   "id": 3, "name": "iPhone 15", ...
  //   "suppliers": [
  //     { "id": 4, "price": 1000, "stock": 10, ... }  ← pricing lives here
  //   ]
  // }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Take the first supplier as the default pricing source.
    // Products with an empty suppliers array are treated as out-of-stock.
    final suppliers = json['suppliers'] as List<dynamic>? ?? [];
    final sp = suppliers.isNotEmpty
        ? suppliers.first as Map<String, dynamic>
        : null;

    return ProductModel(
      // ── Product identity ─────────────────────────────────────────────────
      id: json['id'] as int,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String?,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      sku: json['sku'] as String? ?? '',
      barcode: json['barcode'] as String?,
      slug: json['slug'] as String? ?? '',
      synonyms: json['synonyms'] as String?,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      weight: (json['weight'] as num?)?.toDouble(),
      dimensions: json['dimensions'] as Map<String, dynamic>?,
      categoryId: json['category_id'] as int,
      brandId: json['brand_id'] as int?,
      sortId: json['sort_id'] as int? ?? 0,
      color: json['color'] as String?,
      refundPolicy: json['refund_policy'] as String?,
      refundable: json['refundable'] as bool?,
      refundablePeriod: json['refundable_period'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
      attributes: (json['attributes'] as List<dynamic>?)
          ?.map((e) =>
          ProductAttributeModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      units: (json['units'] as List<dynamic>?)
          ?.map(
              (e) => ProductUnitModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],

      // ── Pricing & stock from suppliers[0] ────────────────────────────────
      spId: sp?['id'] as int?,
      supplierId: sp?['supplier_id'] as int?,
      price: (sp?['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (sp?['cost_price'] as num?)?.toDouble(),
      stock: sp?['stock'] as int? ?? 0,
      minStock: sp?['min_stock'] as int? ?? 0,
      isActive: sp?['is_active'] as bool? ?? false,
      isFeatured: sp?['is_featured'] as bool? ?? false,
      isBestSeller: sp?['is_best_seller'] as bool? ?? false,
      rating: (sp?['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: sp?['total_reviews'] as int? ?? 0,
      maxAmountForOneOrder:
      int.tryParse(sp?['max_amount_for_one_order']?.toString() ?? ''),
      minAmountForOneOrder:
      int.tryParse(sp?['min_amount_for_one_order']?.toString() ?? ''),
      maxAmountForOneUser:
      int.tryParse(sp?['max_amount_for_one_user']?.toString() ?? ''),
      minAmountForOneUser:
      int.tryParse(sp?['min_amount_for_one_user']?.toString() ?? ''),
      reservedInCartsAmount:
      int.tryParse(sp?['reserved_in_carts_amount']?.toString() ?? ''),
      pickupReadyDuration: sp?['pickup_ready_duration'] as int?,

      // ── Offer / discount fields (product-level when available) ────────────
      offer: (json['offer'] as num?)?.toDouble(),
      offerValidFrom: json['offer_valid_from'] != null
          ? DateTime.tryParse(json['offer_valid_from'] as String)
          : null,
      offerValidTo: json['offer_valid_to'] != null
          ? DateTime.tryParse(json['offer_valid_to'] as String)
          : null,
      discountType: json['discount_type'] as String?,
      discountValueTotal: (json['discount_value_total'] as num?)?.toDouble(),
      priceOutSite: (json['price_out_site'] as num?)?.toDouble(),
    );
  }

  // ── Cart factory — sp and product are now sibling keys in the cart item ──────
  //
  // Cart response shape (supplier_product):
  //   {
  //     id, price, stock,
  //     original_price: 1000,   ← full price before discount
  //     unit_price: 850,        ← discounted price (what the user pays)
  //     active_offer: { offer_type: "PERCENT", offer_value: "15", ... }
  //   }
  //
  // Strategy:
  //   • price  = original_price (or price as fallback) — what the product
  //              normally costs. Shown as strikethrough when discounted.
  //   • offer  = unit_price  when unit_price < original_price — the
  //              effective discounted price highlighted in the UI.
  //              null if there is no discount (unit_price == original_price).

  factory ProductModel.fromCartJson({
    required Map<String, dynamic> sp,
    required Map<String, dynamic> product,
  }) {
    final p = product;

    // Resolve original (full) price and the per-unit discounted price.
    final originalPrice =
        (sp['original_price'] as num?)?.toDouble() ??
            (sp['price'] as num?)?.toDouble() ??
            0.0;
    final unitPrice = (sp['unit_price'] as num?)?.toDouble();

    // Only treat unit_price as an "offer" when it is strictly less than the
    // original price.  Equal values mean no active discount.
    final offerPrice =
    (unitPrice != null && unitPrice < originalPrice) ? unitPrice : null;

    return ProductModel(
      // ── Product identity ─────────────────────────────────────────────────
      id: p['id'] as int,
      name: p['name'] as String,
      nameAr: p['name_ar'] as String?,
      description: p['description'] as String?,
      descriptionAr: p['description_ar'] as String?,
      sku: p['sku'] as String? ?? '',
      barcode: p['barcode'] as String?,
      slug: p['slug'] as String? ?? '',
      synonyms: p['synonyms'] as String?,
      images: (p['images'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      weight: (p['weight'] as num?)?.toDouble(),
      dimensions: p['dimensions'] as Map<String, dynamic>?,
      categoryId: p['category_id'] as int? ?? 0,
      brandId: p['brand_id'] as int?,
      sortId: p['sort_id'] as int? ?? 0,
      color: p['color'] as String?,
      refundPolicy: p['refund_policy'] as String?,
      refundable: p['refundable'] as bool?,
      refundablePeriod: p['refundable_period'] as int?,
      createdAt:
      DateTime.tryParse(p['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
      DateTime.tryParse(p['updated_at'] as String? ?? '') ?? DateTime.now(),
      deletedAt: p['deleted_at'] != null
          ? DateTime.tryParse(p['deleted_at'] as String)
          : null,

      // ── Pricing & stock from supplier_product ────────────────────────────
      spId: sp['id'] as int?,
      supplierId: sp['supplier_id'] as int?,
      // price = original (full) price; used as the strikethrough reference.
      price: originalPrice,
      costPrice: (sp['cost_price'] as num?)?.toDouble(),
      stock: sp['stock'] as int? ?? 0,
      minStock: sp['min_stock'] as int? ?? 0,
      isActive: sp['is_active'] as bool? ?? true,
      isFeatured: sp['is_featured'] as bool? ?? false,
      isBestSeller: sp['is_best_seller'] as bool? ?? false,
      rating: (sp['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: sp['total_reviews'] as int? ?? 0,
      maxAmountForOneOrder:
      int.tryParse(sp['max_amount_for_one_order']?.toString() ?? ''),
      minAmountForOneOrder:
      int.tryParse(sp['min_amount_for_one_order']?.toString() ?? ''),
      maxAmountForOneUser:
      int.tryParse(sp['max_amount_for_one_user']?.toString() ?? ''),
      minAmountForOneUser:
      int.tryParse(sp['min_amount_for_one_user']?.toString() ?? ''),
      reservedInCartsAmount:
      int.tryParse(sp['reserved_in_carts_amount']?.toString() ?? ''),
      pickupReadyDuration: sp['pickup_ready_duration'] as int?,

      // ── Offer: unit_price < original_price means an active discount ───────
      // offer  = the discounted unit price (what the user actually pays).
      // discountType = "PERCENT" | "FIXED" from active_offer.offer_type.
      offer: offerPrice,
      discountType: sp['active_offer']?['offer_type'] as String?,
      offerValidFrom: null,
      offerValidTo: null,
      discountValueTotal: null,
      priceOutSite: null,
      attributes: [],
      units: [],
    );
  }

  // ── Computed helpers ───────────────────────────────────────────────────────

  String get displayName => LocaleManager.currentLocale == 'ar' ?  (nameAr ?? name) : name;
  String get displayDescription => descriptionAr ?? description ?? '';
  bool get hasOffer => offer != null && offer! > 0;

  /// Out of stock if no supplier is attached OR supplier stock is zero.
  bool get isOutOfStock => spId == null || stock <= 0;
  bool get isLowStock => stock > 0 && stock <= minStock;
  String? get primaryImage => images.isNotEmpty ? images.first : null;

  double get effectivePrice => hasOffer ? offer! : price;

  /// Discount percentage relative to [price].
  /// Returns null when there is no active offer or price is zero.
  int? get discountPercent {
    if (!hasOffer || price <= 0) return null;
    return ((price - offer!) / price * 100).round();
  }
}