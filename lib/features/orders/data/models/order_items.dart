class OrderItem {
  final int id;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final Product product;

  OrderItem({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      quantity: json['quantity'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
      product: Product.fromJson(json['product']),
    );
  }
}

class Product {
  final String name;
  final String nameAr;
  final bool isRefundable;
  final List<String> images;
  final int? refundablePeriod; // hours, null = no time limit

  Product({
    required this.name,
    required this.nameAr,
    required this.images,
    this.isRefundable = true,
    this.refundablePeriod,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] ?? '',
      nameAr: json['name_ar'] ?? '',
      isRefundable: json['refundable'] == true,
      images: List<String>.from(json['images'] ?? []),
      refundablePeriod: int.tryParse(json['refundable_period']?.toString() ?? ''),
    );
  }

  bool isStillRefundable(DateTime? orderCreatedAt) {
    if (!isRefundable) return false;
    if (refundablePeriod == null) return true;
    if (orderCreatedAt == null) return false; // can't verify, treat as expired
    final deadline = orderCreatedAt.add(Duration(hours: refundablePeriod!));
    return DateTime.now().isBefore(deadline);
  }
}