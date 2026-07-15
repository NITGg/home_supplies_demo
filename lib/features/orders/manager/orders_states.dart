import 'package:equatable/equatable.dart';
import '../data/models/orders_model.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object?> get props => [];
}

// ============== Available Orders States ==============
class AvailableOrdersInitial extends OrderState {}

class AvailableOrdersLoading extends OrderState {
  final bool isLoadingMore;

  const AvailableOrdersLoading({this.isLoadingMore = false});

  @override
  List<Object?> get props => [isLoadingMore];
}

class AvailableOrdersLoaded extends OrderState {
  final List<OrderModel> orders;
  final Map<String, dynamic> pagination;
  final bool hasMore;
  final PriceRangeModel? priceRange;

  const AvailableOrdersLoaded({
    required this.orders,
    required this.pagination,
    required this.hasMore,
    this.priceRange,
  });

  @override
  List<Object?> get props => [orders, pagination, hasMore, priceRange];
}

class AvailableOrdersError extends OrderState {
  final String message;

  const AvailableOrdersError(this.message);

  @override
  List<Object?> get props => [message];
}

// ============== Order History States ==============
class OrderHistoryInitial extends OrderState {}

class OrderHistoryLoading extends OrderState {
  final bool isLoadingMore;

  const OrderHistoryLoading({this.isLoadingMore = false});

  @override
  List<Object?> get props => [isLoadingMore];
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

  @override
  List<Object?> get props => [orders, pagination, hasMore, currentFilter];
}

class OrderHistoryError extends OrderState {
  final String message;

  const OrderHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

// ============== Order Details States ==============
class OrderDetailsLoading extends OrderState {}

class OrderDetailsLoaded extends OrderState {
  final OrderModel order;
  final FeeRangeModel? feeRange;

  const OrderDetailsLoaded({required this.order, this.feeRange});

  @override
  List<Object?> get props => [order, feeRange];
}

class OrderDetailsError extends OrderState {
  final String message;

  const OrderDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}

// ============== Submit Offer States ==============
class SubmittingOffer extends OrderState {}

class OfferSubmitted extends OrderState {
  final ProposalModel proposal;
  final int orderId;

  const OfferSubmitted(this.proposal, this.orderId);

  @override
  List<Object?> get props => [proposal, orderId];
}

class OfferSubmitError extends OrderState {
  final String message;
  final OrderModel? order;
  final FeeRangeModel? feeRange;

  const OfferSubmitError(this.message, {this.order, this.feeRange});

  @override
  List<Object?> get props => [message, order, feeRange];
}

// ============== Fixed-Fee Response States ==============
class RespondingToFixedFee extends OrderState {
  final String action; // 'ACCEPT' or 'REJECT'
  const RespondingToFixedFee(this.action);

  @override
  List<Object?> get props => [action];
}

class FixedFeeResponseSuccess extends OrderState {
  final String action; // 'ACCEPT' or 'REJECT'
  const FixedFeeResponseSuccess(this.action);

  @override
  List<Object?> get props => [action];
}

class FixedFeeResponseError extends OrderState {
  final String message;
  final OrderModel? order;
  const FixedFeeResponseError(this.message, {this.order});

  @override
  List<Object?> get props => [message, order];
}

// ============== Active Order States ==============
class ActiveOrderInitial extends OrderState {}

class ActiveOrderLoading extends OrderState {}

class ActiveOrderLoaded extends OrderState {
  final List<OrderModel> orders;
  const ActiveOrderLoaded(this.orders);

  // Backward-compat getter used elsewhere in the codebase
  OrderModel get order => orders.first;

  @override
  List<Object?> get props => [orders];
}

class NoActiveOrder extends OrderState {}

class ActiveOrderError extends OrderState {
  final String message;
  final OrderModel? order;

  const ActiveOrderError(this.message, {this.order});

  @override
  List<Object?> get props => [message, order];
}

// ============== Complete Delivery States ==============
class CompletingDelivery extends OrderState {}

class DeliveryCompleted extends OrderState {
  final QrCodeModel qrCode;
  final int? orderId;
  final double actualPrice;
  final int courierId;
  final int customerId;

  const DeliveryCompleted(
      this.qrCode,
      this.orderId, {
        required this.actualPrice,
        required this.courierId,
        required this.customerId,
      });

  @override
  List<Object?> get props => [qrCode, orderId, actualPrice, courierId, customerId];
}

class DeliveryCompleteError extends OrderState {
  final String message;
  final OrderModel? order;

  const DeliveryCompleteError(this.message, {this.order});

  @override
  List<Object?> get props => [message, order];
}

// ============== Report High Price States ==============
class ReportingHighPrice extends OrderState {}

class HighPriceReported extends OrderState {}

class HighPriceReportError extends OrderState {
  final String message;
  final OrderModel? order;

  const HighPriceReportError(this.message, {this.order});

  @override
  List<Object?> get props => [message, order];
}

// ============== Cancel Order States ==============
class CancelingOrder extends OrderState {}

class OrderCancelled extends OrderState {
  final OrderModel order;

  const OrderCancelled(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderCancelError extends OrderState {
  final String message;
  final OrderModel? order;

  const OrderCancelError(this.message, {this.order});

  @override
  List<Object?> get props => [message, order];
}

// ============== Order Collected States ==============
class CollectingOrder extends OrderState {}

class OrderCollected extends OrderState {
  final OrderModel order;

  const OrderCollected(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderCollectError extends OrderState {
  final String message;
  final OrderModel? order;

  const OrderCollectError(this.message, {this.order});

  @override
  List<Object?> get props => [message, order];
}

class ConfirmingWithOtp extends OrderState {}

class ConfirmWithOtpSuccess extends OrderState {}

class ConfirmWithOtpError extends OrderState {
  final String message;
  const ConfirmWithOtpError(this.message);

  @override
  List<Object?> get props => [message];
}

class FinalConfirmingDelivery extends OrderState {}

class FinalConfirmSuccess extends OrderState {}

class FinalConfirmError extends OrderState {
  final String message;
  const FinalConfirmError(this.message);

  @override
  List<Object?> get props => [message];
}