class CartSupplierLimitsModel {
  /// EGP value — server sends piasters (cents) as a string, divided by 100.
  final double? minPriceForOneOrder;

  /// EGP value — server sends piasters (cents) as a string, divided by 100.
  /// Null when the supplier has no maximum configured.
  final double? maxPriceForOneOrder;

  const CartSupplierLimitsModel({
    this.minPriceForOneOrder,
    this.maxPriceForOneOrder,
  });

  factory CartSupplierLimitsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CartSupplierLimitsModel();

    double? parse(dynamic value) {
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed == null || parsed <= 0) return null;
      return parsed / 100.0;
    }

    return CartSupplierLimitsModel(
      minPriceForOneOrder: parse(json['min_price_for_one_order']),
      maxPriceForOneOrder: parse(json['max_price_for_one_order']),
    );
  }
}
