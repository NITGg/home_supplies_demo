class CartSummaryModel {
  final int itemCount;
  final int totalItems;
  final double totalPrice;

  const CartSummaryModel({
    required this.itemCount,
    required this.totalItems,
    required this.totalPrice,
  });

  factory CartSummaryModel.fromJson(Map<String, dynamic> json) {
    return CartSummaryModel(
      itemCount: json['itemCount'] as int? ?? 0,
      totalItems: json['totalItems'] as int? ?? 0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}