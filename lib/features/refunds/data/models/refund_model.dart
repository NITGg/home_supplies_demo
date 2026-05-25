
class RefundReason {
  final int id;
  final String reasonEn;
  final String reasonAr;

  const RefundReason({
    required this.id,
    required this.reasonEn,
    required this.reasonAr,
  });

  factory RefundReason.fromJson(Map<String, dynamic> json) {
    return RefundReason(
      id: json['id'] as int,
      reasonEn: json['reason_en'] as String,
      reasonAr: json['reason_ar'] as String,
    );
  }

  String localizedReason(String languageCode) =>
      languageCode == 'ar' ? reasonAr : reasonEn;
}

class RefundReasonsResponse {
  final List<RefundReason> reasons;
  final int total;
  final int totalPages;

  const RefundReasonsResponse({
    required this.reasons,
    required this.total,
    required this.totalPages,
  });

  factory RefundReasonsResponse.fromJson(Map<String, dynamic> json) {
    return RefundReasonsResponse(
      reasons: (json['refundReasons'] as List<dynamic>)
          .map((e) => RefundReason.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['totalRefundReasons'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

// ── Refund ────────────────────────────────────────────────────────────────────

class Refund {
  final int id;
  final int orderId;
  final double amount;
  final String currency;
  final List<String>? evidenceImages;
  final String reason;
  final String status;
  final bool isFullRefund;
  final String? rawResponse;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const Refund({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.currency,
    this.evidenceImages,
    required this.reason,
    required this.status,
    required this.isFullRefund,
    this.rawResponse,
    this.reviewedAt,
    required this.createdAt,
  });

  factory Refund.fromJson(Map<String, dynamic> json) {
    List<String>? images;
    final raw = json['evidence_images'];
    if (raw is List) {
      images = raw.map((e) => e.toString()).toList();
    }

    return Refund(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      amount: ((json['amount'] as num?) ?? 0) / 100.0,
      currency: (json['currency'] as String?) ?? 'EGP',
      evidenceImages: images,
      reason: json['reason'] as String,
      status: json['status'] as String,
      isFullRefund: json['is_full_refund'] == true,
      rawResponse: json['raw_response'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at']).toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  bool get isPending => status == 'REQUESTED' || status == 'PROCESSING';
  bool get isApproved => status == 'APPROVED' || status == 'COMPLETED';
  bool get isRejected => status == 'REJECTED' || status == 'CANCELLED' || status == 'FAILED';
}

class RefundsListResponse {
  final List<Refund> refunds;
  final int total;
  final int totalPages;

  const RefundsListResponse({
    required this.refunds,
    required this.total,
    required this.totalPages,
  });

  factory RefundsListResponse.fromJson(Map<String, dynamic> json) {
    return RefundsListResponse(
      refunds: (json['refunds'] as List<dynamic>)
          .map((e) => Refund.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['totalRefunds'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

// ── Request payload ───────────────────────────────────────────────────────────

class RefundItemRequest {
  final int orderItemId;
  final int quantity;

  const RefundItemRequest({
    required this.orderItemId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'order_item_id': orderItemId,
    'quantity': quantity,
  };
}