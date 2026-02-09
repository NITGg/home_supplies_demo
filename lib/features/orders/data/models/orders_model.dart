class OrderModel {
  final int id;
  final String orderNumber;
  final String productDescription;
  final String? productImage;
  final String budget;
  final String? actualPrice;
  final String pickupAddressDescription;
  final double pickupLat;
  final double pickupLong;
  final String deliveryAddressDescription;
  final double deliveryLat;
  final double deliveryLong;
  final String? totalFee;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? offerAcceptedAt;
  final DateTime? deliveredAt;
  final DateTime? canceledAt;
  final String? cancelledReason;
  final int? cancelledBy;
  final AreaModel? pickupArea;
  final AreaModel? deliveryArea;
  final CustomerModel? customer;
  final int? proposalsCount;
  final bool? hasMyProposal;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.productDescription,
    this.productImage,
    required this.budget,
    this.actualPrice,
    required this.pickupAddressDescription,
    required this.pickupLat,
    required this.pickupLong,
    required this.deliveryAddressDescription,
    required this.deliveryLat,
    required this.deliveryLong,
    this.totalFee,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.offerAcceptedAt,
    this.deliveredAt,
    this.canceledAt,
    this.cancelledReason,
    this.cancelledBy,
     this.pickupArea,
     this.deliveryArea,
     this.customer,
    this.proposalsCount,
    this.hasMyProposal,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      orderNumber: json['order_number'],
      productDescription: json['product_description'],
      productImage: json['product_image'],
      budget: json['budget'],
      actualPrice: json['actual_price'],
      pickupAddressDescription: json['pickup_address_description'],
      pickupLat: double.parse(json['pickup_lat'].toString()),
      pickupLong: double.parse(json['pickup_long'].toString()),
      deliveryAddressDescription: json['delivery_address_description'],
      deliveryLat: double.parse(json['delivery_lat'].toString()),
      deliveryLong: double.parse(json['delivery_long'].toString()),
      totalFee: json['total_fee'],
      paymentMethod: json['payment_method'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      offerAcceptedAt: json['offer_accepted_at'] != null
          ? DateTime.parse(json['offer_accepted_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      canceledAt: json['canceled_at'] != null
          ? DateTime.parse(json['canceled_at'])
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
    double? pickupLat,
    double? pickupLong,
    String? deliveryAddressDescription,
    double? deliveryLat,
    double? deliveryLong,
    String? totalFee,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    DateTime? offerAcceptedAt,
    DateTime? deliveredAt,
    DateTime? canceledAt,
    String? cancelledReason,
    int? cancelledBy,
    AreaModel? pickupArea,
    AreaModel? deliveryArea,
    CustomerModel? customer,
    int? proposalsCount,
    bool? hasMyProposal,
  }) {
    return OrderModel(
      id: id ?? this.id,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      offerAcceptedAt: offerAcceptedAt ?? this.offerAcceptedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      canceledAt: canceledAt ?? this.canceledAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      pickupArea: pickupArea ?? this.pickupArea,
      deliveryArea: deliveryArea ?? this.deliveryArea,
      customer: customer ?? this.customer,
      proposalsCount: proposalsCount ?? this.proposalsCount,
      hasMyProposal: hasMyProposal ?? this.hasMyProposal,
    );
  }

  // Helper method to check if order is cancelled
  bool get isCancelled => status == 'CANCELLED';

  // Helper method to check if order is delivered
  bool get isDelivered => status == 'DELIVERED';

  // Helper method to check if order is in progress
  bool get isInProgress => status == 'IN_PROGRESS';
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

class QrCodeModel {
  final String qrCode;
  final int orderId;

  QrCodeModel({required this.qrCode, required this.orderId});

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(qrCode: json['qr_code'], orderId: json['order_id']);
  }
}
