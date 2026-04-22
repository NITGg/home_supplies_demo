class OrderPreviewModel {
  final double deliveryFee;
  final double vatAmount;
  final double totalFee;

  const OrderPreviewModel({
    required this.deliveryFee,
    required this.vatAmount,
    required this.totalFee,
  });

  factory OrderPreviewModel.fromJson(Map<String, dynamic> json) {
    final p = json['preview'] as Map<String, dynamic>;
    return OrderPreviewModel(
      deliveryFee: (p['deliveryFee'] as num).toDouble()/100,
      vatAmount:   (p['vatAmount']   as num).toDouble()/100,
      totalFee:    (p['totalFee']    as num).toDouble()/100,
    );
  }
}