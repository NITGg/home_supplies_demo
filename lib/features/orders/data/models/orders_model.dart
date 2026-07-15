import 'package:flutter/cupertino.dart';

import 'order_items.dart';

class OrderModel {
  final int id;
  final int? courierId;
  final String orderNumber;
  final String? productDescription; // ✅ now nullable
  final String? productImage;
  final String? budget;             // ✅ now nullable
  final String? actualPrice;

  final String? costPrice;
  final String pickupAddressDescription;
  final String? pickupLat;
  final String? pickupLong;
  final String? distanceM;
  final String deliveryAddressDescription;
  final String? deliveryLat;
  final String? deliveryLong;
  final String? totalFee;
  final String? discountAmount;
  final String? courierFee;
  final String? platformFee;        // ✅ new
  final String? vatAmount;          // ✅ new
  final String? productsTotal;      // ✅ new
  final String? payableAmount;      // ✅ new
  final String paymentMethod;
  final String status;
  final String? type;               // ✅ new (e.g. CATALOG_PURCHASE)
  final bool isFixedFee;            // ✅ new
  final DateTime createdAt;
  final DateTime? offerAcceptedAt;
  final String? couponType;
  final DateTime? deliveredAt;
  final DateTime? collectedAt;
  final DateTime? canceledAt;
  final DateTime? proposalsDeadlineAt; // ✅ new
  final DateTime? expiresAt;           // ✅ new
  final String? cancelledReason;
  final int? cancelledBy;
  final AreaModel? pickupArea;
  final AreaModel? deliveryArea;
  final CustomerModel? customer;
  final int? proposalsCount;
  final List<ProposalHistoryModel>? proposalHistory;

  final List<OrderItem> orderItems;

  // ✅ Set client-side when the order's price falls outside the courier's
  // currently allowed price range. Not parsed from JSON.
  final bool isOutOfPriceRange;

  OrderModel({
    required this.id,
    required this.orderNumber,
    this.productDescription,
    this.productImage,
    this.discountAmount,
    this.budget,
    required this.orderItems,
    this.actualPrice,
    this.costPrice,
    this.courierId,
    this.couponType,
    this.distanceM,
    required this.pickupAddressDescription,
    required this.pickupLat,
    required this.pickupLong,
    required this.deliveryAddressDescription,
    required this.deliveryLat,
    required this.deliveryLong,
    this.totalFee,
    this.courierFee,
    this.platformFee,
    this.vatAmount,
    this.productsTotal,
    this.payableAmount,
    required this.paymentMethod,
    required this.status,
    this.type,
    this.isFixedFee = false,
    required this.createdAt,
    this.collectedAt,
    this.offerAcceptedAt,
    this.deliveredAt,
    this.canceledAt,
    this.proposalsDeadlineAt,
    this.expiresAt,
    this.cancelledReason,
    this.cancelledBy,
    this.pickupArea,
    this.deliveryArea,
    this.customer,
    this.proposalsCount,
    this.proposalHistory,
    this.isOutOfPriceRange = false,
  });

  // ✅ Helper: parse a nullable numeric field to a rounded string
  static String? _parseAmount(dynamic value) {
    if (value == null) return null;
    final parsed = (num.tryParse(value.toString()) ?? 0)/100;
    return parsed.toStringAsFixed(2);
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      couponType: json['coupon_type'] as String?,
      id: json['id'],
      courierId: json['courier_id'],
      orderNumber: json['order_number'],
      productDescription: json['product_description'],
      productImage: json['product_image'],
      // ✅ distanceM can now be a double or null — convert to string safely
      distanceM: json['distance_m']?.toString(),
      orderItems: (json['orderItems'] as List? ?? [])
          .map((e) => OrderItem.fromJson(e))
          .toList(),
      budget: _parseAmount(json['budget']),
      actualPrice: _parseAmount(json['actual_price']),
      costPrice: _parseAmount(json['total_cost_price']),
      pickupAddressDescription: json['pickup_address_description'],
      pickupLat: json['pickup_lat']?.toString(),
      pickupLong: json['pickup_long']?.toString(),
      deliveryAddressDescription: json['delivery_address_description'],
      deliveryLat: json['delivery_lat']?.toString(),
      deliveryLong: json['delivery_long']?.toString(),
      totalFee: _parseAmount(json['total_fee']),
      discountAmount: _parseAmount(json['discount_amount']),
      courierFee: _parseAmount(json['courier_fee']),
      platformFee: _parseAmount(json['platform_fee']),
      vatAmount: _parseAmount(json['vat_amount']),
      productsTotal: _parseAmount(json['products_total']),
      payableAmount: _parseAmount(json['payable_amount']),
      paymentMethod: json['payment_method'],
      status: json['status'],
      type: json['type'],
      isFixedFee: json['is_fixed_fee'] ?? false,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      offerAcceptedAt: json['offer_accepted_at'] != null
          ? DateTime.parse(json['offer_accepted_at']).toLocal()
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at']).toLocal()
          : null,
      canceledAt: json['canceled_at'] != null
          ? DateTime.parse(json['canceled_at']).toLocal()
          : null,
      collectedAt: json['order_collected_at'] != null
          ? DateTime.parse(json['order_collected_at']).toLocal()
          : null,
      proposalsDeadlineAt: json['proposals_deadline_at'] != null
          ? DateTime.parse(json['proposals_deadline_at']).toLocal()
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at']).toLocal()
          : null,
      cancelledReason: json['cancelled_reason'],
      cancelledBy: json['cancelled_by'],
      pickupArea: json['pickup_area'] != null
          ? AreaModel.fromJson(json['pickup_area'])
          : null,
      deliveryArea: json['delivery_area'] != null
          ? AreaModel.fromJson(json['delivery_area'])
          : null,
      customer: json['customer'] != null
          ? CustomerModel.fromJson(json['customer'])
          : null,
      proposalsCount: json['_count']?['proposals'],
      proposalHistory: (json['proposalHistory'] ?? json['proposals']) != null
          ? ((json['proposalHistory'] ?? json['proposals']) as List)
          .map((e) => ProposalHistoryModel.fromJson(e))
          .toList()
          : null,
    );
  }

  OrderModel copyWith({
    int? id,
    String? orderNumber,
    String? productDescription,
    String? productImage,
    String? budget,
    String? actualPrice,
    String? pickupAddressDescription,
    String? pickupLat,
    String? pickupLong,
    String? deliveryAddressDescription,
    String? deliveryLat,
    String? deliveryLong,
    String? totalFee,
    String? discountAmount,
    String? courierFee,
    String? platformFee,
    String? couponType,

    String? vatAmount,
    String? productsTotal,
    String? payableAmount,
    String? paymentMethod,
    String? status,
    String? type,
    bool? isFixedFee,
    DateTime? createdAt,
    DateTime? offerAcceptedAt,
    DateTime? deliveredAt,
    DateTime? canceledAt,
    DateTime? proposalsDeadlineAt,
    DateTime? expiresAt,
    String? cancelledReason,
    int? cancelledBy,
    AreaModel? pickupArea,
    AreaModel? deliveryArea,
    CustomerModel? customer,
    int? proposalsCount,
    List<ProposalHistoryModel>? proposalHistory,
    bool? isOutOfPriceRange,
  }) {
    return OrderModel(
      id: id ?? this.id,
      couponType: couponType ?? this.couponType,
      orderNumber: orderNumber ?? this.orderNumber,
      productDescription: productDescription ?? this.productDescription,
      productImage: productImage ?? this.productImage,
      budget: budget ?? this.budget,
      actualPrice: actualPrice ?? this.actualPrice,
      pickupAddressDescription:
      pickupAddressDescription ?? this.pickupAddressDescription,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLong: pickupLong ?? this.pickupLong,
      deliveryAddressDescription:
      deliveryAddressDescription ?? this.deliveryAddressDescription,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLong: deliveryLong ?? this.deliveryLong,
      totalFee: totalFee ?? this.totalFee,
      discountAmount: discountAmount ?? this.discountAmount,
      courierFee: courierFee ?? this.courierFee,
      platformFee: platformFee ?? this.platformFee,
      vatAmount: vatAmount ?? this.vatAmount,
      productsTotal: productsTotal ?? this.productsTotal,
      payableAmount: payableAmount ?? this.payableAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      type: type ?? this.type,
      isFixedFee: isFixedFee ?? this.isFixedFee,
      createdAt: createdAt ?? this.createdAt,
      offerAcceptedAt: offerAcceptedAt ?? this.offerAcceptedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      canceledAt: canceledAt ?? this.canceledAt,
      proposalsDeadlineAt: proposalsDeadlineAt ?? this.proposalsDeadlineAt,
      expiresAt: expiresAt ?? this.expiresAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      pickupArea: pickupArea ?? this.pickupArea,
      deliveryArea: deliveryArea ?? this.deliveryArea,
      customer: customer ?? this.customer,
      proposalsCount: proposalsCount ?? this.proposalsCount,
      proposalHistory: proposalHistory ?? this.proposalHistory, orderItems: [],
      isOutOfPriceRange: isOutOfPriceRange ?? this.isOutOfPriceRange,
    );
  }

  bool get hasDeliveryFeeDiscount => couponType == 'DELIVERY_FEE' && _hasNonZeroDiscount;
  bool get hasProductsOnlyDiscount => couponType == 'PRODUCTS_ONLY' && _hasNonZeroDiscount;
  bool get hasOrderTotalDiscount => couponType == 'ORDER_TOTAL' && _hasNonZeroDiscount;

  bool get _hasNonZeroDiscount =>
      discountAmount != null &&
          discountAmount != '0' &&
          discountAmount != '0.0' &&
          discountAmount != '0.00';

  bool get isCancelled => status == 'CANCELLED';
  bool get isDelivered => status == 'DELIVERED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCatalogPurchase => type == 'CATALOG_PURCHASE'; // ✅ new

  // ✅ Check if proposals deadline has passed
  bool get isProposalsExpired =>
      proposalsDeadlineAt != null &&
          DateTime.now().isAfter(proposalsDeadlineAt!);

  bool get canSubmitProposal {
    debugPrint('--- canSubmitProposal CHECK ---');
    debugPrint('Order ID: $id');
    debugPrint('status: $status');
    debugPrint('isProposalsExpired: $isProposalsExpired');
    debugPrint('proposalHistory length: ${proposalHistory?.length}');

    if (status != 'PENDING') {
      debugPrint('❌ Not PENDING → cannot submit');
      return false;
    }

    if (isProposalsExpired) {
      debugPrint('❌ Proposals expired → cannot submit');
      return false;
    }

    if (proposalHistory == null || proposalHistory!.isEmpty) {
      debugPrint('✅ No proposal history → can submit');
      return true;
    }

    final latestProposal = proposalHistory!.last;
    debugPrint('latestProposal.status: ${latestProposal.status}');

    final canSubmit = latestProposal.status == 'REJECTED';

    if (canSubmit) {
      debugPrint('✅ Last proposal REJECTED → can resubmit');
    } else {
      debugPrint('❌ Last proposal NOT rejected → cannot submit');
    }

    debugPrint('RESULT: $canSubmit');
    return canSubmit;
  }

  String? get currentProposalStatus {
    if (proposalHistory == null || proposalHistory!.isEmpty) return null;
    return proposalHistory!.first.status;
  }

  bool get hasPendingProposal => currentProposalStatus == 'PENDING';
  bool get lastProposalWasRejected => currentProposalStatus == 'REJECTED';
}
class ProposalHistoryModel {
  final int id;
  final int orderId;
  final int? courierId;
  final String totalFee;
  final String status; // PENDING, ACCEPTED, REJECTED
  final DateTime createdAt;
  final DateTime? confirmedAt;

  ProposalHistoryModel({
    required this.id,
    required this.orderId,
    required this.courierId,
    required this.totalFee,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
  });

  factory ProposalHistoryModel.fromJson(Map<String, dynamic> json) {
    return ProposalHistoryModel(
      id: json['id'],
      orderId: json['order_id'],
      courierId: json['courier_id'],
      totalFee:
          ((num.tryParse(json['total_fee']?.toString() ?? '0') ?? 0) / 100)
              .round()
              .toString(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'])
          : null,
    );
  }

  bool get isPending => status == 'PENDING';

  bool get isAccepted => status == 'ACCEPTED';

  bool get isRejected => status == 'REJECTED';
}

class AreaModel {
  final int id;
  final String name;
  final String nameAr;
  final GovernorateModel? governorate;

  AreaModel({
    required this.id,
    required this.name,
    required this.nameAr,
    this.governorate,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['id'],
      name: json['name'],
      nameAr: json['name_ar'],
      governorate: json['governorate'] != null
          ? GovernorateModel.fromJson(json['governorate'])
          : null,
    );
  }
}

class GovernorateModel {
  final int id;
  final String name;
  final String nameAr;

  GovernorateModel({
    required this.id,
    required this.name,
    required this.nameAr,
  });

  factory GovernorateModel.fromJson(Map<String, dynamic> json) {
    return GovernorateModel(
      id: json['id'],
      name: json['name'],
      nameAr: json['name_ar'],
    );
  }
}

class CustomerModel {
  final int id;
  final String fullName;
  final String? personalPhoto;
  final String? phone;

  CustomerModel({
    required this.id,
    required this.fullName,
    this.personalPhoto,
    this.phone,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      fullName: json['full_name'],
      personalPhoto: json['personal_photo'],
      phone: json['phone'],
    );
  }
}

class FeeRangeModel {
  final double minDeliveryFee;
  final double maxDeliveryFee;

  FeeRangeModel({required this.minDeliveryFee, required this.maxDeliveryFee});

  factory FeeRangeModel.fromJson(Map<String, dynamic> json) {
    return FeeRangeModel(
      minDeliveryFee: (json['min_delivery_fee'] as num).toDouble(),
      maxDeliveryFee: (json['max_delivery_fee'] as num).toDouble(),
    );
  }
}

class ProposalModel {
  final int id;
  final int orderId;
  final int courierId;
  final String totalFee;
  final String status;
  final DateTime createdAt;

  ProposalModel({
    required this.id,
    required this.orderId,
    required this.courierId,
    required this.totalFee,
    required this.status,
    required this.createdAt,
  });

  factory ProposalModel.fromJson(Map<String, dynamic> json) {
    return ProposalModel(
      id: json['id'],
      orderId: json['order_id'],
      courierId: json['courier_id'],
      totalFee: json['total_fee'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class PriceRangeModel {
  final double minOrderPrice;
  final double maxOrderPrice;
  final double currentOrdersValue;
  final double allowedMinOrderPrice;
  final double allowedMaxOrderPrice;

  PriceRangeModel({
    required this.minOrderPrice,
    required this.maxOrderPrice,
    required this.currentOrdersValue,
    required this.allowedMinOrderPrice,
    required this.allowedMaxOrderPrice,
  });

  // ✅ Values come from the API in cents, same convention as `budget`/`products_total`.
  static double _parsePrice(dynamic value) {
    return (num.tryParse(value?.toString() ?? '0') ?? 0) / 100;
  }

  factory PriceRangeModel.fromJson(Map<String, dynamic> json) {
    return PriceRangeModel(
      minOrderPrice: _parsePrice(json['min_order_price']),
      maxOrderPrice: _parsePrice(json['max_order_price']),
      currentOrdersValue: _parsePrice(json['current_orders_value']),
      allowedMinOrderPrice: _parsePrice(json['allowed_min_order_price']),
      allowedMaxOrderPrice: _parsePrice(json['allowed_max_order_price']),
    );
  }
}

class QrCodeModel {
  final String qrCode;
  final int orderId;

  QrCodeModel({required this.qrCode, required this.orderId});

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(qrCode: json['qr_code'], orderId: json['order_id']);
  }
}
