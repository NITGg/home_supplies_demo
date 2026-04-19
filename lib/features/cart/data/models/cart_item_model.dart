import '../../../products/data/models/product_model.dart';

class CartItemModel {
  final int id;
  final int cartId;
  final int spId;
  final int quantity;

  /// Merged supplier + product data — use [product.spId] for cart PUT/DELETE calls.
  final ProductModel product;

  final double unitPrice;
  final double originalPrice;
  final double lineTotal;

  const CartItemModel({
    required this.id,
    required this.cartId,
    required this.spId,
    required this.quantity,
    required this.product,
    required this.unitPrice,
    required this.originalPrice,
    required this.lineTotal,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final sp = json['supplier_product'] as Map<String, dynamic>;
    final p  = json['product']          as Map<String, dynamic>;

    return CartItemModel(
      id:            json['id']       as int,
      cartId:        json['cart_id']  as int,
      spId:          json['sp_id']    as int,
      quantity:      json['quantity'] as int? ?? 1,
      product:       ProductModel.fromCartJson(sp: sp, product: p),
      unitPrice:     (sp['unit_price']    as num?)?.toDouble() ?? 0.0,
      originalPrice: (sp['original_price'] as num?)?.toDouble() ?? 0.0,
      lineTotal:     (json['line_total']   as num?)?.toDouble() ?? 0.0,
    );
  }

  CartItemModel copyWithQuantity(int newQuantity) {
    return CartItemModel(
      id: id,
      cartId: cartId,
      spId: spId,
      quantity: newQuantity,
      product: product,
      unitPrice: unitPrice,
      originalPrice: originalPrice,
      lineTotal: unitPrice * newQuantity,
    );
  }
}