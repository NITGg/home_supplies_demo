import 'dart:io';

class Order {
  final int? id;
  final int? customerId;
  final int? courierId;
  final String? orderNumber;
  final String productDescription;
  final String? productImage;
  final File? productImageFile;
  final String budget;
  final String? actualPrice;
  final int pickupAreaId;
  final String pickupAddressDescription;
  final String? pickupLat;
  final String? pickupLong;
  final int deliveryAreaId;
  final String deliveryAddressDescription;
  final String? deliveryLat;
  final String? deliveryLong;
  final String? minDeliveryFee;
  final String? maxDeliveryFee;
  final String? totalFee;
  final String? courierFee;
  final String? platformFee;
  final String? paymentMethod;
  final String? status;
  final String? cancelledReason;
  final String? cancellationFee;
  final int? cancelledBy;
  final int? proposalsCount;
  final DateTime? createdAt;
  final DateTime? offerAcceptedAt;
  final DateTime? deliveredAt;
  final DateTime? canceledAt;
  final String? courierName;
  final String? courierPhone;
  final String? courierPhoto; // ← NEW: courier avatar URL
  final String?
  priceAdjustmentStatus; // ← NEW: NONE | ACCEPTED | REJECTED | PENDING

  Order({
    this.courierName,
    this.courierPhone,
    this.courierPhoto,
    this.priceAdjustmentStatus,
    this.id,
    this.customerId,
    this.courierId,
    this.orderNumber,
    required this.productDescription,
    this.productImage,
    this.productImageFile,
    required this.budget,
    this.actualPrice,
    required this.pickupAreaId,
    required this.pickupAddressDescription,
    required this.pickupLat,
    required this.pickupLong,
    required this.deliveryAreaId,
    required this.deliveryAddressDescription,
    required this.deliveryLat,
    required this.deliveryLong,
    this.minDeliveryFee,
    this.maxDeliveryFee,
    this.totalFee,
    this.courierFee,
    this.platformFee,
    this.paymentMethod,
    this.status,
    this.cancelledReason,
    this.cancellationFee,
    this.cancelledBy,
    this.proposalsCount,
    this.createdAt,
    this.offerAcceptedAt,
    this.deliveredAt,
    this.canceledAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final courier = json['courier'] as Map<String, dynamic>?;
    final user = courier?['user'] as Map<String, dynamic>?;

    return Order(
      courierName: user?['full_name'] as String?,
      courierPhone: user?['phone'] as String?,
      courierPhoto: user?['personal_photo'] as String?,
      priceAdjustmentStatus: json['price_adjustment_status'] as String?,

      id: json['id'] as int?,
      customerId: json['customer_id'] as int?,
      courierId: json['courier_id'] as int?,
      orderNumber: json['order_number'] as String?,
      productDescription: json['product_description'] as String,
      productImage: json['product_image'] as String?,
      budget: ((num.tryParse(json['budget']?.toString() ?? '0') ?? 0) / 100)
          .toStringAsFixed(0),
      actualPrice:
          ((num.tryParse(json['actual_price']?.toString() ?? '0') ?? 0) / 100)
              .toStringAsFixed(0),
      pickupAreaId: json['pickup_area_id'] as int,
      pickupAddressDescription: json['pickup_address_description'] as String,
      pickupLat: json['pickup_lat'],
      pickupLong: json['pickup_long'],
      deliveryAreaId: json['delivery_area_id'] as int,
      deliveryAddressDescription:
          json['delivery_address_description'] as String,
      deliveryLat: json['delivery_lat'],
      deliveryLong: json['delivery_long'],
      minDeliveryFee: json['min_delivery_fee']?.toString(),
      maxDeliveryFee: json['max_delivery_fee']?.toString(),
      totalFee: json['total_fee']?.toString(),
      courierFee: json['courier_fee']?.toString(),
      platformFee: json['platform_fee']?.toString(),
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String?,
      cancelledReason: json['cancelled_reason'] as String?,
      cancellationFee: json['cancellation_fee']?.toString(),
      cancelledBy: json['cancelled_by'] as int?,
      proposalsCount: json['proposals_count'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      offerAcceptedAt: json['offer_accepted_at'] != null
          ? DateTime.parse(json['offer_accepted_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      canceledAt: json['canceled_at'] != null
          ? DateTime.parse(json['canceled_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_description': productDescription,
      if (productImage != null) 'product_image': productImage,
      'budget': budget,
      'pickup_area_id': pickupAreaId,
      'pickup_address_description': pickupAddressDescription,
      'pickup_lat': pickupLat,
      'pickup_long': pickupLong,
      'delivery_area_id': deliveryAreaId,
      'delivery_address_description': deliveryAddressDescription,
      'delivery_lat': deliveryLat,
      'delivery_long': deliveryLong,
    };
  }

  bool get isPending => status == 'PENDING';

  bool get isAccepted => status == 'ACCEPTED';

  bool get isDelivered => status == 'DELIVERED';

  bool get isCancelled => status == 'CANCELLED';

  bool get hasProposals => (proposalsCount ?? 0) > 0;

  /// True when the courier proposed a new price and we're waiting for customer response
  bool get hasPendingPriceAdjustment => priceAdjustmentStatus == 'PENDING';
}

class OrderResponse {
  final String message;
  final Order order;

  OrderResponse({required this.message, required this.order});

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      message: json['message'] as String,
      order: Order.fromJson(json['order'] as Map<String, dynamic>),
    );
  }
}

class OrdersListResponse {
  final List<Order> orders;
  final int totalOrders;
  final int totalPages;

  OrdersListResponse({
    required this.orders,
    required this.totalOrders,
    required this.totalPages,
  });

  factory OrdersListResponse.fromJson(Map<String, dynamic> json) {
    return OrdersListResponse(
      orders: (json['orders'] as List<dynamic>)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalOrders: json['totalOrders'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
