// ==================== Wallet Model ====================
class WalletModel {
  final int id;
  final int userId;
  final String ownerType;
  final double balance;
  final double? points;
  final String status;
  final String? freezeReason;
  final DateTime? frozenAt;
  final int? frozenBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletModel({
    required this.id,
    required this.userId,
    required this.ownerType,
    required this.balance,
    this.points,
    required this.status,
    this.freezeReason,
    this.frozenAt,
    this.frozenBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      ownerType: json['owner_type'] as String,
      balance: ((json['balance'] as num) / 100).toDouble(),
      points: ((json['points'] as num)).toDouble(),
      status: json['status'] as String,
      freezeReason: json['freeze_reason'] as String?,
      frozenAt: json['frozen_at'] != null
          ? DateTime.parse(json['frozen_at'] as String)
          : null,
      frozenBy: json['frozen_by'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isActive => status == 'ACTIVE';

  bool get isFrozen => status != 'ACTIVE';
}

// ==================== Transaction Model ====================
class WalletTransactionModel {
  final int id;
  final int walletId;
  final int? orderId;
  final int? escrowId;
  final int? paymentMethodId;
  final int? processedBy;
  final String type;
  final String status;
  final String? rejectReason;
  final double amount;
  final String? description;
  final String? paymobOrderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletTransactionModel({
    required this.id,
    required this.walletId,
    this.orderId,
    this.escrowId,
    this.paymentMethodId,
    this.processedBy,
    required this.type,
    required this.status,
    this.rejectReason,
    required this.amount,
    required this.description,
    this.paymobOrderId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as int,
      walletId: json['wallet_id'] as int,
      orderId: json['order_id'] as int?,
      escrowId: json['escrow_id'] as int?,
      paymentMethodId: json['payment_method_id'] as int?,
      processedBy: json['processed_by'] as int?,
      type: json['type'] as String,
      status: json['status'] as String,
      rejectReason: json['reject_reason'] as String?,
      amount: (double.tryParse(json['amount'].toString()) ?? 0) / 100,
      description: json['description'] as String?,
      paymobOrderId: json['paymob_order_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  bool get isPositive =>
      type == 'TOPUP' || type == 'MANUAL_INCREASE' || type == 'ESCROW_RELEASE';

  bool get isNegative =>
      type == 'WITHDRAWAL' ||
      type == 'PENALTY' ||
      type == 'COUPON_PURCHASE' ||
      type == 'MANUAL_DECREASE' ||
      type == 'COMMISSION_DEDUCTION';

  bool get isCompleted => status == 'COMPLETED';

  bool get isFailed => status == 'FAILED';

  bool get isPending => status == 'PENDING';
}

// ==================== Penalty Model ====================
class PenaltyModel {
  final int id;
  final int? userId;
  final int? createdBy;
  final double amount;
  final String? reason;
  final bool isPaid;
  final DateTime? paidAt;
  final bool isWaived;
  final DateTime? waivedAt;
  final int? waivedBy;
  final DateTime createdAt;
  final int? orderId;

  PenaltyModel({
    required this.id,
    this.userId,
    this.createdBy,
    required this.amount,
    this.reason,
    required this.isPaid,
    this.paidAt,
    required this.isWaived,
    this.waivedAt,
    this.waivedBy,
    required this.createdAt,
    this.orderId,
  });

  factory PenaltyModel.fromJson(Map<String, dynamic> json) {
    return PenaltyModel(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      createdBy: json['created_by'] as int?,
      amount: (double.tryParse(json['amount'].toString()) ?? 0) / 100,
      reason: json['reason'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String).toLocal()
          : null,
      isWaived: json['is_waived'] as bool? ?? false,
      waivedAt: json['waived_at'] != null
          ? DateTime.parse(json['waived_at'] as String).toLocal()
          : null,
      waivedBy: json['waived_by'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      orderId: json['order_id'] as int?,
    );
  }

  String get statusText {
    if (isWaived) return 'WAIVED';
    if (isPaid) return 'COMPLETED';
    return 'PENDING';
  }
}

// ==================== Unpaid Commission Model ====================
class UnpaidCommissionModel {
  final int id;
  final int orderId;
  final int courierId;
  final double amount;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime? paidAt;

  UnpaidCommissionModel({
    required this.id,
    required this.orderId,
    required this.courierId,
    required this.amount,
    required this.isPaid,
    required this.createdAt,
    this.paidAt,
  });

  factory UnpaidCommissionModel.fromJson(Map<String, dynamic> json) {
    return UnpaidCommissionModel(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      courierId: json['user_id'] as int,
      amount: (double.tryParse(json['amount'].toString()) ?? 0) / 100,
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String).toLocal()
          : null,
    );
  }
}

// ==================== Pagination Model (used by Transactions) ====================
class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      totalPages: json['total_pages'] as int,
    );
  }

  bool get hasMore => page < totalPages;
}

// ==================== Skip/Limit Pagination Model (used by Penalties & Commissions) ====================
/// The new API response for penalties/commissions no longer nests a pagination
/// object. Instead it returns `totalPenalties` / `totalCommissions` and
/// `totalPages` at the top level of `data`. This model captures that shape and
/// also tracks the current `skip` so the cubit can compute the next batch.
class SkipLimitPaginationModel {
  final int skip;
  final int limit;
  final int total;
  final int totalPages;

  SkipLimitPaginationModel({
    required this.skip,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  /// Returns `true` when there are more items beyond what has already been
  /// loaded (i.e. we haven't yet fetched everything).
  bool get hasMore => (skip + limit) < total;

  /// The `skip` value to pass when requesting the next page.
  int get nextSkip => skip + limit;
}

