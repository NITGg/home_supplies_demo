
/// Thrown when the backend rejects an add-to-cart request because the new
/// item belongs to a different supplier than the items already in the cart.
///
/// Backend response shape:
/// ```json
/// {
///   "message": "Cart items must all come from the same supplier...",
///   "code": "MULTIPLE_SUPPLIERS",
///   "data": {
///     "current_supplier_id": 1,
///     "attempted_supplier_id": 3
///   }
/// }
/// ```
class MultipleSupplierException implements Exception {
  final int currentSupplierId;
  final int attemptedSupplierId;
  final String message;

  /// The [spId] and [quantity] that triggered the conflict, forwarded so
  /// the UI can retry automatically after clearing the cart.
  final int pendingSpId;
  final int pendingQuantity;

  const MultipleSupplierException({
    required this.currentSupplierId,
    required this.attemptedSupplierId,
    required this.message,
    required this.pendingSpId,
    required this.pendingQuantity,
  });

  @override
  String toString() => 'MultipleSupplierException: $message '
      '(current=$currentSupplierId, attempted=$attemptedSupplierId)';
}