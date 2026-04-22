import 'dart:convert';

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

  // ── Type-coercion helpers ─────────────────────────────────────────────────
  //
  // The backend is inconsistent: numeric fields arrive as int, as "10"
  // (string), or as null.  These helpers normalise all three cases so neither
  // factory needs a single hard `as int?` / `as double?` cast.

  static int? _parseInt(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());

  static int _parseIntOr0(dynamic v) => _parseInt(v) ?? 0;

  static double? _parseDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  static double _parseDoubleOr0(dynamic v) => _parseDouble(v) ?? 0.0;

  /// Parses a monetary value sent by the backend in **cents** and converts it
  /// to EGP by dividing by 100.  Returns null when the raw value is absent.
  static double? _parseCents(dynamic v) {
    final raw = _parseDouble(v);
    return raw == null ? null : raw / 100.0;
  }

  /// Like [_parseCents] but returns 0.0 instead of null.
  static double _parseCentsOr0(dynamic v) => _parseCents(v) ?? 0.0;

  /// Accepts true/false booleans AND "true"/"false" strings.
  static bool _parseBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    return v.toString().toLowerCase() == 'true';
  }

  /// Accepts a real List, a JSON-encoded string ("[\"url\"]"), or null.
  static List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return [raw]; // bare URL string
      }
    }
    return [];
  }

  /// synonyms can arrive as a plain String or as a JSON List.
  static String? _parseSynonyms(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is List) return v.join(', ');
    return v.toString();
  }

  /// dimensions can arrive as a Map or as a plain String ("20x15x8 cm").
  static Map<String, dynamic>? _parseDimensions(dynamic v) {
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  // ── Products list / detail API ────────────────────────────────────────────
  //
  // Response shape:
  // {
  //   "id": 3, "name": "iPhone 15", ...
  //   "images": "[\"https://...\"]",   ← JSON-encoded string, List, or null
  //   "supplier_data": {               ← single object (not an array)
  //     "id": 4,
  //     "original_price": 100000,      ← cents (÷100 → 1000.00 EGP)
  //     "unit_price": 85000,           ← cents (÷100 →  850.00 EGP)
  //     "active_offer": { "offer_type": "PERCENT", ... } | null
  //   }
  // }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final sp = json['supplier_data'] as Map<String, dynamic>?;

    final originalPrice =
        _parseCents(sp?['original_price']) ??
            _parseCents(sp?['price']) ??
            0.0;
    final unitPrice  = _parseCents(sp?['unit_price']);
    final offerPrice =
    (unitPrice != null && unitPrice < originalPrice) ? unitPrice : null;

    return ProductModel(
      // ── Product identity ─────────────────────────────────────────────────
      id:            _parseIntOr0(json['id']),
      name:          json['name'] as String,
      nameAr:        json['name_ar'] as String?,
      description:   json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      sku:           json['sku']?.toString() ?? '',
      barcode:       json['barcode'] as String?,
      slug:          json['slug']?.toString() ?? '',
      synonyms:      _parseSynonyms(json['synonyms']),
      images:        _parseImages(json['images']),
      weight:        _parseDouble(json['weight']),
      dimensions:    _parseDimensions(json['dimensions']),
      categoryId:    _parseIntOr0(json['category_id']),
      brandId:       _parseInt(json['brand_id']),
      sortId:        _parseIntOr0(json['sort_id']),
      color:         json['color'] as String?,
      refundPolicy:  json['refund_policy'] as String?,
      refundable:    json['refundable'] as bool?,
      refundablePeriod: _parseInt(json['refundable_period']),
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
          ?.map((e) =>
          ProductUnitModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],

      // ── Pricing & stock from supplier_data ───────────────────────────────
      spId:         _parseInt(sp?['id']),
      supplierId:   _parseInt(sp?['supplier_id']),
      price:        originalPrice,
      costPrice:    _parseCents(sp?['cost_price']),
      stock:        _parseIntOr0(sp?['stock']),
      minStock:     _parseIntOr0(sp?['min_stock']),
      isActive:     _parseBool(sp?['is_active']),
      isFeatured:   _parseBool(sp?['is_featured']),
      isBestSeller: _parseBool(sp?['is_best_seller']),
      rating:       _parseDoubleOr0(sp?['rating']),
      totalReviews: _parseIntOr0(sp?['total_reviews']),
      maxAmountForOneOrder:  _parseInt(sp?['max_amount_for_one_order']),
      minAmountForOneOrder:  _parseInt(sp?['min_amount_for_one_order']),
      maxAmountForOneUser:   _parseInt(sp?['max_amount_for_one_user']),
      minAmountForOneUser:   _parseInt(sp?['min_amount_for_one_user']),
      reservedInCartsAmount: _parseInt(sp?['reserved_in_carts_amount']),
      pickupReadyDuration:   _parseInt(sp?['pickup_ready_duration']),

      // ── Offer: unit_price < original_price means an active discount ───────
      offer:        offerPrice,
      discountType: sp?['active_offer']?['offer_type'] as String?,
      offerValidFrom: sp?['active_offer']?['start_date'] != null
          ? DateTime.tryParse(sp!['active_offer']['start_date'] as String)
          : null,
      offerValidTo: sp?['active_offer']?['end_date'] != null
          ? DateTime.tryParse(sp!['active_offer']['end_date'] as String)
          : null,
      discountValueTotal: _parseCents(sp?['active_offer']?['offer_value']),
      priceOutSite:       _parseCents(json['price_out_site']),
    );
  }

  // ── Cart factory ──────────────────────────────────────────────────────────
  //
  // Cart response shape (supplier_product):
  //   {
  //     id, price, stock,
  //     original_price: 100000,  ← cents (÷100 → 1000.00 EGP)
  //     unit_price: 85000,       ← cents (÷100 →  850.00 EGP)
  //     active_offer: { offer_type: "PERCENT", offer_value: "15", ... }
  //   }

  factory ProductModel.fromCartJson({
    required Map<String, dynamic> sp,
    required Map<String, dynamic> product,
  }) {
    final p = product;

    final originalPrice =
        _parseCents(sp['original_price']) ??
            _parseCents(sp['price']) ??
            0.0;
    final unitPrice  = _parseCents(sp['unit_price']);
    final offerPrice =
    (unitPrice != null && unitPrice < originalPrice) ? unitPrice : null;

    return ProductModel(
      // ── Product identity ─────────────────────────────────────────────────
      id:            _parseIntOr0(p['id']),
      name:          p['name'] as String,
      nameAr:        p['name_ar'] as String?,
      description:   p['description'] as String?,
      descriptionAr: p['description_ar'] as String?,
      sku:           p['sku']?.toString() ?? '',
      barcode:       p['barcode'] as String?,
      slug:          p['slug']?.toString() ?? '',
      synonyms:      _parseSynonyms(p['synonyms']),
      images:        _parseImages(p['images']),
      weight:        _parseDouble(p['weight']),
      dimensions:    _parseDimensions(p['dimensions']),
      categoryId:    _parseIntOr0(p['category_id']),
      brandId:       _parseInt(p['brand_id']),
      sortId:        _parseIntOr0(p['sort_id']),
      color:         p['color'] as String?,
      refundPolicy:  p['refund_policy'] as String?,
      refundable:    p['refundable'] as bool?,
      refundablePeriod: _parseInt(p['refundable_period']),
      createdAt:
      DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt:
      DateTime.tryParse(p['updated_at']?.toString() ?? '') ?? DateTime.now(),
      deletedAt: p['deleted_at'] != null
          ? DateTime.tryParse(p['deleted_at'] as String)
          : null,

      // ── Pricing & stock from supplier_product ─────────────────────────────
      spId:         _parseInt(sp['id']),
      supplierId:   _parseInt(sp['supplier_id']),
      price:        originalPrice,
      costPrice:    _parseCents(sp['cost_price']),
      stock:        _parseIntOr0(sp['stock']),
      minStock:     _parseIntOr0(sp['min_stock']),
      isActive:     _parseBool(sp['is_active'], fallback: true),
      isFeatured:   _parseBool(sp['is_featured']),
      isBestSeller: _parseBool(sp['is_best_seller']),
      rating:       _parseDoubleOr0(sp['rating']),
      totalReviews: _parseIntOr0(sp['total_reviews']),
      maxAmountForOneOrder:  _parseInt(sp['max_amount_for_one_order']),
      minAmountForOneOrder:  _parseInt(sp['min_amount_for_one_order']),
      maxAmountForOneUser:   _parseInt(sp['max_amount_for_one_user']),
      minAmountForOneUser:   _parseInt(sp['min_amount_for_one_user']),
      reservedInCartsAmount: _parseInt(sp['reserved_in_carts_amount']),
      pickupReadyDuration:   _parseInt(sp['pickup_ready_duration']),

      // ── Offer ─────────────────────────────────────────────────────────────
      offer:             offerPrice,
      discountType:      sp['active_offer']?['offer_type'] as String?,
      offerValidFrom:    null,
      offerValidTo:      null,
      discountValueTotal: null,
      priceOutSite:      null,
      attributes: [],
      units:      [],
    );
  }

  // ── Computed helpers ───────────────────────────────────────────────────────

  String get displayName =>
      LocaleManager.currentLocale == 'ar' ? (nameAr ?? name) : name;
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