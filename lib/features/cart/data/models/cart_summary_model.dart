class CartSummaryModel {
  final int itemCount;
  final int totalItems;

  /// Sum of each item's original (un-discounted) line total.
  /// Computed locally from cart items — the server does not send this field.
  final double originalTotal;

  /// Total amount saved across all discounted lines.
  /// Computed locally — originalTotal - subtotal.
  final double totalDiscount;

  /// Final price the customer actually pays.
  final double subtotal;

  const CartSummaryModel({
    required this.itemCount,
    required this.totalItems,
    required this.originalTotal,
    required this.totalDiscount,
    required this.subtotal,
  });

  /// Legacy getter so any existing caller of [totalPrice] keeps compiling.
  double get totalPrice => subtotal;

  bool get hasDiscount => totalDiscount > 0;

  /// Parses the server payload.
  /// The server only sends itemCount / totalItems / totalPrice, so
  /// originalTotal and totalDiscount are set to safe neutral values here.
  /// The cubit always overwrites this with a locally-computed summary
  /// (via [CartCubit._computeSummary]) immediately after a fetch, so
  /// these neutral values are never actually displayed.
  factory CartSummaryModel.fromJson(Map<String, dynamic> json) {
    final subtotal = (json['totalPrice'] as num?)?.toDouble() ?? 0.0;
    return CartSummaryModel(
      itemCount: json['itemCount'] as int? ?? 0,
      totalItems: json['totalItems'] as int? ?? 0,
      originalTotal: subtotal, // neutral: no discount until recomputed
      totalDiscount: 0.0,       // neutral
      subtotal: subtotal,
    );
  }
}