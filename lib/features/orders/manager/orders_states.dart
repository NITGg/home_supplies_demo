import '../data/models/orders_model.dart';

abstract class OrderState {
  const OrderState();
}

// ============== Available Orders States ==============
class AvailableOrdersInitial extends OrderState {}

class AvailableOrdersLoading extends OrderState {}

class AvailableOrdersLoaded extends OrderState {
  final List<OrderModel> orders;
  final Map<String, dynamic> pagination;

  const AvailableOrdersLoaded({
    required this.orders,
    required this.pagination,
  });
}

class AvailableOrdersError extends OrderState {
  final String message;

  const AvailableOrdersError(this.message);
}

// ============== Order Details States ==============
class OrderDetailsLoading extends OrderState {}

class OrderDetailsLoaded extends OrderState {
  final OrderModel order;
  final FeeRangeModel? feeRange;

  const OrderDetailsLoaded({
    required this.order,
    this.feeRange,
  });
}

class OrderDetailsError extends OrderState {
  final String message;

  const OrderDetailsError(this.message);
}

// ============== Submit Offer States ==============
class SubmittingOffer extends OrderState {}

class OfferSubmitted extends OrderState {
  final ProposalModel proposal;

  const OfferSubmitted(this.proposal);
}

class OfferSubmitError extends OrderState {
  final String message;

  const OfferSubmitError(this.message);
}

// ============== Active Order States ==============
class ActiveOrderInitial extends OrderState {}

class ActiveOrderLoading extends OrderState {}

class ActiveOrderLoaded extends OrderState {
  final OrderModel order;

  const ActiveOrderLoaded(this.order);
}

class NoActiveOrder extends OrderState {}

class ActiveOrderError extends OrderState {
  final String message;

  const ActiveOrderError(this.message);
}

// ============== Complete Delivery States ==============
class CompletingDelivery extends OrderState {}

class DeliveryCompleted extends OrderState {
  final QrCodeModel qrCode;

  const DeliveryCompleted(this.qrCode);
}

class DeliveryCompleteError extends OrderState {
  final String message;

  const DeliveryCompleteError(this.message);
}
