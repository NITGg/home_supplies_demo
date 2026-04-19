
class CartModel {
  final int id;
  final double totalPrice;

  const CartModel({
    required this.id,
    required this.totalPrice,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: json['id'] as int,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
    );
  }
}