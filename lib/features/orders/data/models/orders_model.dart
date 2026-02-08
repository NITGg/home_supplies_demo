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
  final AreaModel pickupArea;
  final AreaModel deliveryArea;
  final CustomerModel customer;
  final int? proposalsCount;

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
    required this.pickupArea,
    required this.deliveryArea,
    required this.customer,
    this.proposalsCount,
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
      pickupLat: double.parse(json['pickup_lat']),
      pickupLong: double.parse(json['pickup_long']),
      deliveryAddressDescription: json['delivery_address_description'],
      deliveryLat: double.parse(json['delivery_lat']),
      deliveryLong: double.parse(json['delivery_long']),
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
      pickupArea: AreaModel.fromJson(json['pickup_area']),
      deliveryArea: AreaModel.fromJson(json['delivery_area']),
      customer: CustomerModel.fromJson(json['customer']),
      proposalsCount: json['_count'] != null ? json['_count']['proposals'] : null,
    );
  }
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

  FeeRangeModel({
    required this.minDeliveryFee,
    required this.maxDeliveryFee,
  });

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

  QrCodeModel({
    required this.qrCode,
    required this.orderId,
  });

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(
      qrCode: json['qr_code'],
      orderId: json['order_id'],
    );
  }
}