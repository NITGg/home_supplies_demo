class DeliveryQRCode {
  final int orderId;
  final int courierId;
  final String action;
  final DateTime timestamp;

  DeliveryQRCode({
    required this.orderId,
    required this.courierId,
    required this.action,
    required this.timestamp,
  });

  factory DeliveryQRCode.fromJson(Map<String, dynamic> json) {
    return DeliveryQRCode(
      orderId: json['orderId'] as int,
      courierId: json['courierId'] as int,
      action: json['action'] as String,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'courierId': courierId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isConfirmDelivery => action == 'CONFIRM_DELIVERY';
}

class ConfirmDeliveryRequest {
  final int orderId;
  final int courierId;

  ConfirmDeliveryRequest({
    required this.orderId,
    required this.courierId,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'courier_id': courierId,
    };
  }
}