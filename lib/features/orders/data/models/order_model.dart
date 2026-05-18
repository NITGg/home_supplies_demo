import 'dart:io';

import 'order_items.dart';

class Order {
  String get itemsSummary {
    if (orderItems.isEmpty) return '';

    return orderItems
        .map((item) {
          final name = item.product.nameAr.isNotEmpty
              ? item.product.nameAr
              : item.product.name;

          return '$name (${item.quantity})';
        })
        .join(' ');
  }

  final int? id;
  final int? customerId;
  final int? courierId;
  final int? courierUserId;
  final String? orderNumber;
  final String? type;
  final String? productDescription; // was required String
  final String? productImage;
  final File? productImageFile;
  final String? budget; // was required String
  final String? actualPrice;
  final int? pickupAreaId; // was required int
  final String? pickupAddressDescription; // was required String
  final String? pickupLat;
  final String? confirmationOtp;
  final String? pickupLong;
  final int? deliveryAreaId; // was required int
  final String? deliveryAddressDescription; // was required String
  final String? deliveryLat;
  final String? deliveryLong;
  final String? minDeliveryFee;
  final String? maxDeliveryFee;
  final String? totalFee;
  final String? discountAmount;
  final String? courierFee;
  final String? platformFee;
  final String? paymentMethod;
  final String? status;
  final String? couponType;
  final String? cancelledReason;
  final String? cancellationFee;
  final int? cancelledBy;
  final int? proposalsCount;
  final DateTime? createdAt;
  final DateTime? offerAcceptedAt;
  final DateTime? deliveredAt;
  final DateTime? canceledAt;
  final DateTime? collectedAt;

  final DateTime? expiresAt;
  final String? courierName;
  final String? courierPhone;
  final String? payableAmount; // ✅ new

  final String? courierPhoto; // ← NEW: courier avatar URL
  final String?
  priceAdjustmentStatus; // ← NEW: NONE | ACCEPTED | REJECTED | PENDING

  final List<OrderItem> orderItems;

  Order({
    this.courierName,
    this.confirmationOtp,
    this.type,
    this.courierPhone,
    this.courierPhoto,
    this.priceAdjustmentStatus,
    this.id,
    this.couponType,
    this.customerId,
    this.courierId,
    this.courierUserId,
    this.orderNumber,
    this.productDescription, // no longer required
    this.productImage,
    this.productImageFile,
    this.budget, // no longer required
    this.actualPrice,
    this.collectedAt,
    this.pickupAreaId, // no longer required
    this.pickupAddressDescription, // no longer required
    this.pickupLat,
    this.pickupLong,
    this.deliveryAreaId, // no longer required
    this.deliveryAddressDescription, // no longer required
    required this.deliveryLat,
    required this.deliveryLong,
    required this.orderItems,
    this.minDeliveryFee,
    this.maxDeliveryFee,
    this.totalFee,
    this.discountAmount,
    this.courierFee,
    this.platformFee,
    this.paymentMethod,
    this.status,
    this.cancelledReason,
    this.payableAmount,

    this.cancellationFee,
    this.cancelledBy,
    this.proposalsCount,
    this.createdAt,
    this.offerAcceptedAt,
    this.deliveredAt,
    this.canceledAt,
    this.expiresAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final courier = json['courier'] as Map<String, dynamic>?;
    final user = courier?['user'] as Map<String, dynamic>?;

    return Order(
      orderItems: (json['orderItems'] as List? ?? [])
          .map((e) => OrderItem.fromJson(e))
          .toList(),
      type: json['type'] as String?,
      couponType: json['coupon_type'] as String?,
      confirmationOtp: json['confirmation_otp'] as String?,
      courierName: user?['full_name'] as String?,
      courierPhone: user?['phone'] as String?,
      courierUserId: user?['id'] as int?,
      courierPhoto: user?['personal_photo'] as String?,
      priceAdjustmentStatus: json['price_adjustment_status'] as String?,
      id: json['id'] as int?,
      customerId: json['customer_id'] as int?,
      courierId: json['courier_id'] as int?,
      orderNumber: json['order_number'] as String?,
      productDescription: json['product_description'] as String?,
      // nullable
      productImage: json['product_image'] as String?,
      budget: json['budget'] == null
          ? null
          : ((num.tryParse(json['budget'].toString()) ?? 0) / 100).toString(),

      payableAmount: json['payable_amount'] == null
          ? null
          : ((num.tryParse(json['payable_amount'].toString()) ?? 0) / 100)
                .toString(),
      actualPrice: json['actual_price'] == null
          ? null
          : ((num.tryParse(json['actual_price'].toString()) ?? 0) / 100)
                .toString(),
      pickupAreaId: json['pickup_area_id'] as int?,
      // nullable
      pickupAddressDescription: json['pickup_address_description'] as String?,
      // nullable
      pickupLat: json['pickup_lat']?.toString(),
      pickupLong: json['pickup_long']?.toString(),
      deliveryAreaId: json['delivery_area_id'] as int?,
      // nullable
      deliveryAddressDescription:
          json['delivery_address_description'] as String?,
      // nullable
      deliveryLat: json['delivery_lat']?.toString(),
      deliveryLong: json['delivery_long']?.toString(),
      minDeliveryFee: json['min_delivery_fee']?.toString(),
      maxDeliveryFee: json['max_delivery_fee']?.toString(),
      totalFee: json['total_fee']?.toString(),
      discountAmount: json['discount_amount']?.toString(),
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
      collectedAt: json['order_collected_at'] != null
          ? DateTime.parse(json['order_collected_at']).toLocal()
          : null,
      offerAcceptedAt: json['offer_accepted_at'] != null
          ? DateTime.parse(json['offer_accepted_at']).toLocal()
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at']).toLocal()
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at']).toLocal()
          : null,
      canceledAt: json['canceled_at'] != null
          ? DateTime.parse(json['canceled_at']).toLocal()
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

  bool get isInProgress => status == 'IN_PROGRESS';

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
