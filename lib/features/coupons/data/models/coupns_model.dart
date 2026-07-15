// ==================== Available Coupon Model ====================
// Maps to: data.coupons[]
class AvailableCouponModel {
  final int id;
  final String title;
  final String titleAr;
  final String description;
  final String descriptionAr;
  final double price;
  final double bonusCourierFee;
  final int durationDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  AvailableCouponModel({
    required this.id,
    required this.title,
    required this.titleAr,
    required this.description,
    required this.descriptionAr,
    required this.price,
    required this.bonusCourierFee,
    required this.durationDays,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory AvailableCouponModel.fromJson(Map<String, dynamic> json) {
    return AvailableCouponModel(
      id: json['id'] as int,
      title: json['title'] as String,
      titleAr: json['title_ar'] as String,
      description: json['description'] as String,
      descriptionAr: json['description_ar'] as String,
      price: ((num.tryParse(json['price']?.toString() ?? '0') ?? 0) / 100),
      bonusCourierFee:
      double.tryParse(json['bonus_courier_fee'].toString()) ?? 0,
      durationDays: json['duration_days'] as int,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toLocal()
          : null,
    );
  }
}

// ==================== Active Coupon Model ====================
// Maps to: data.activeCoupon  (and each item in data.couponHistory[])
// Real fields: id, user_id, coupon_id, start_date, end_date,
//              snapshot_price, snapshot_bonus_courier_fee, created_at, coupon{}
class ActiveCouponModel {
  final int id;
  final int userId;
  final int couponId;
  final DateTime startDate;
  final DateTime endDate;
  final double snapshotPrice;
  final double snapshotBonusCourierFee;
  final DateTime createdAt;
  final AvailableCouponModel? coupon;

  ActiveCouponModel({
    required this.id,
    required this.userId,
    required this.couponId,
    required this.startDate,
    required this.endDate,
    required this.snapshotPrice,
    required this.snapshotBonusCourierFee,
    required this.createdAt,
    this.coupon,
  });

  bool get isExpired => DateTime.now().isAfter(endDate);

  int get daysRemaining =>
      endDate.difference(DateTime.now()).inDays.clamp(0, 9999);

  factory ActiveCouponModel.fromJson(Map<String, dynamic> json) {
    return ActiveCouponModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      couponId: json['coupon_id'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      snapshotPrice:
      double.tryParse(json['snapshot_price'].toString()) ?? 0,
      snapshotBonusCourierFee:
      double.tryParse(json['snapshot_bonus_courier_fee'].toString()) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      coupon: json['coupon'] != null
          ? AvailableCouponModel.fromJson(
          json['coupon'] as Map<String, dynamic>)
          : null,
    );
  }
}

// History items have the exact same shape — reuse via typedef
typedef CouponHistoryModel = ActiveCouponModel;

// ==================== Coupon Pagination Model ====================
class CouponPaginationModel {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  CouponPaginationModel({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory CouponPaginationModel.fromJson(Map<String, dynamic> json) {
    return CouponPaginationModel(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['total_pages'] as int,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrev: json['has_prev'] as bool? ?? false,
    );
  }
}