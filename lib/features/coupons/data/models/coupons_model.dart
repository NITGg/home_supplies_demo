class Coupon {
  final int id;
  final String code;
  final String title;
  final String? titleAr;
  final String? description;
  final String? descriptionAr;
  final String type; // 'WALLET_CREDIT' or 'ORDER_DISCOUNT'
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final int? maxTotalUses;
  final int? maxUserUses;
  final int minOrdersCount;
  final String? discountType; // 'PERCENT' or 'FIXED'
  final double? discountValue;
  final int? maxDiscountCents;
  final int? minOrderTotalCents;
  final int walletAmountCents;
  final int walletPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Coupon({
    required this.id,
    required this.code,
    required this.title,
    this.titleAr,
    this.description,
    this.descriptionAr,
    required this.type,
    this.startAt,
    this.endAt,
    required this.isActive,
    this.maxTotalUses,
    this.maxUserUses,
    required this.minOrdersCount,
    this.discountType,
    this.discountValue,
    this.maxDiscountCents,
    this.minOrderTotalCents,
    required this.walletAmountCents,
    required this.walletPoints,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isWalletCredit => type == 'WALLET_CREDIT';
  bool get isOrderDiscount => type == 'ORDER_DISCOUNT';
  bool get isPercentDiscount => discountType == 'PERCENT';

  /// Wallet credit amount in major currency unit
  double get walletAmount => walletAmountCents / 100;

  /// Max discount amount in major currency unit
  double? get maxDiscount =>
      maxDiscountCents != null ? maxDiscountCents! / 100 : null;

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as int,
      code: json['code'] as String,
      title: json['title'] as String,
      titleAr: json['title_ar'] as String?,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      type: json['type'] as String,
      startAt: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'] as String)
          : null,
      endAt: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'] as String)
          : null,
      isActive: json['is_active'] as bool,
      maxTotalUses: json['max_total_uses'] as int?,
      maxUserUses: json['max_user_uses'] as int?,
      minOrdersCount: (json['min_orders_count'] as num?)?.toInt() ?? 0,
      discountType: json['discount_type'] as String?,
      discountValue: (json['discount_value'] as num?)?.toDouble(),
      maxDiscountCents: json['max_discount_cents'] as int?,
      minOrderTotalCents: json['min_order_total_cents'] as int?,
      walletAmountCents: (json['wallet_amount_cents'] as num?)?.toInt() ?? 0,
      walletPoints: (json['wallet_points'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CouponsResponse {
  final int totalCoupons;
  final int totalPages;
  final List<Coupon> coupons;

  const CouponsResponse({
    required this.totalCoupons,
    required this.totalPages,
    required this.coupons,
  });

  factory CouponsResponse.fromJson(Map<String, dynamic> json) {
    return CouponsResponse(
      totalCoupons: json['totalCoupons'] as int,
      totalPages: json['totalPages'] as int,
      coupons: (json['coupons'] as List<dynamic>)
          .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}