import '../data/models/orders_model.dart';

abstract class OrderState {
  const OrderState();
}

// ============== Available Orders States ==============
class AvailableOrdersInitial extends OrderState {}

class AvailableOrdersLoading extends OrderState {
  final bool isLoadingMore;

  const AvailableOrdersLoading({this.isLoadingMore = false});
}

class AvailableOrdersLoaded extends OrderState {
  final List<OrderModel> orders;
  final Map<String, dynamic> pagination;
  final bool hasMore;

  const AvailableOrdersLoaded({
    required this.orders,
    required this.pagination,
    required this.hasMore,
  });
}

class AvailableOrdersError extends OrderState {
  final String message;

  const AvailableOrdersError(this.message);
}

// ============== Order History States ==============
class OrderHistoryInitial extends OrderState {}

class OrderHistoryLoading extends OrderState {
  final bool isLoadingMore;

  const OrderHistoryLoading({this.isLoadingMore = false});
}

class OrderHistoryLoaded extends OrderState {
  final List<OrderModel> orders;
  final Map<String, dynamic> pagination;
  final bool hasMore;
  final String currentFilter;

  const OrderHistoryLoaded({
    required this.orders,
    required this.pagination,
    required this.hasMore,
    required this.currentFilter,
  });
}

class OrderHistoryError extends OrderState {
  final String message;

  const OrderHistoryError(this.message);
}

// ============== Order Details States ==============
class OrderDetailsLoading extends OrderState {}

class OrderDetailsLoaded extends OrderState {
  final OrderModel order;
  final FeeRangeModel? feeRange;

  const OrderDetailsLoaded({required this.order, this.feeRange});
}

class OrderDetailsError extends OrderState {
  final String message;

  const OrderDetailsError(this.message);
}

// ============== Submit Offer States ==============
class SubmittingOffer extends OrderState {}

class OfferSubmitted extends OrderState {
  final ProposalModel proposal;
  final int orderId;

  const OfferSubmitted(this.proposal, this.orderId);
}

class OfferSubmitError extends OrderState {
  final String message;
  final OrderModel? order;
  final FeeRangeModel? feeRange;

  const OfferSubmitError(this.message, {this.order, this.feeRange});
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
  final OrderModel? order;

  const ActiveOrderError(this.message, {this.order});
}

// ============== Complete Delivery States ==============
class CompletingDelivery extends OrderState {}

class DeliveryCompleted extends OrderState {
  final QrCodeModel qrCode;

  const DeliveryCompleted(this.qrCode);
}

class DeliveryCompleteError extends OrderState {
  final String message;
  final OrderModel? order;

  const DeliveryCompleteError(this.message, {this.order});
}

// ============== Report High Price States ==============
class ReportingHighPrice extends OrderState {}

class HighPriceReported extends OrderState {
}

class HighPriceReportError extends OrderState {
  final String message;
  final OrderModel? order;

  const HighPriceReportError(this.message, {this.order});
}

// ============== Cancel Order States ==============
class CancelingOrder extends OrderState {}

class OrderCancelled extends OrderState {
  final OrderModel order;

  const OrderCancelled(this.order);
}

class OrderCancelError extends OrderState {
  final String message;
  final OrderModel? order;

  const OrderCancelError(this.message, {this.order});
}
