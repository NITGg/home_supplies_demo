class OrderPreviewModel {
  final double courierFee;
  final double deliveryFee;
  final double platformFee;
  final double vatAmount;
  final double totalFee;

  const OrderPreviewModel({
    required this.deliveryFee,
    required this.platformFee,
    required this.courierFee,
    required this.vatAmount,
    required this.totalFee,
  });

  factory OrderPreviewModel.fromJson(Map<String, dynamic> json) {
    final p = json['preview'] as Map<String, dynamic>;
    return OrderPreviewModel(
      platformFee: (p['platformFee'] as num).toDouble()/100,
      deliveryFee: (p['deliveryFee'] as num).toDouble()/100,
      courierFee: (p['courierFee'] as num).toDouble()/100,
      vatAmount:   (p['vatAmount']   as num).toDouble()/100,
      totalFee:    (p['totalFee']    as num).toDouble()/100,
    );
  }
}