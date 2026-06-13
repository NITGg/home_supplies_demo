import 'cart_model.dart';
import 'cart_item_model.dart';
import 'cart_summary_model.dart';
import 'cart_supplier_limits_model.dart';

class CartResponseModel {
  final CartModel cart;
  final List<CartItemModel> cartItems;
  final CartSummaryModel summary;
  final CartSupplierLimitsModel supplierLimits;

  const CartResponseModel({
    required this.cart,
    required this.cartItems,
    required this.summary,
    this.supplierLimits = const CartSupplierLimitsModel(),
  });

  factory CartResponseModel.fromJson(Map<String, dynamic> json) {
    return CartResponseModel(
      cart: CartModel.fromJson(json['cart'] as Map<String, dynamic>),
      cartItems: (json['cartItems'] as List<dynamic>? ?? [])
          .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: CartSummaryModel.fromJson(
          json['cartSummary'] as Map<String, dynamic>),
      supplierLimits: CartSupplierLimitsModel.fromJson(
          json['supplier'] as Map<String, dynamic>?),
    );
  }

  CartResponseModel copyWith({
    CartModel? cart,
    List<CartItemModel>? cartItems,
    CartSummaryModel? summary,
    CartSupplierLimitsModel? supplierLimits,
  }) {
    return CartResponseModel(
      cart: cart ?? this.cart,
      cartItems: cartItems ?? this.cartItems,
      summary: summary ?? this.summary,
      supplierLimits: supplierLimits ?? this.supplierLimits,
    );
  }
}