import '../data/models/order_model.dart';
import '../data/models/proposal_model.dart';

abstract class OrderState {
  const OrderState();

  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

/// Full-screen loading (first load only — list is empty).
class OrderLoading extends OrderState {}

/// Pagination append — list already visible, spinner at bottom.
class OrdersLoadingMore extends OrderState {}

/// Background operation in progress (create / cancel / accept / reject).
/// The UI keeps showing the existing [OrdersLoaded] state — this is only
/// consumed by listeners for the loading indicator on action buttons.
class OrderOperationLoading extends OrderState {}

// ── Create Order ──────────────────────────────────────────────────────────────

class OrderSuccess extends OrderState {
  final String message;
  final Order order;

  const OrderSuccess({required this.message, required this.order});

  @override
  List<Object?> get props => [message, order];
}

// ── Orders List ───────────────────────────────────────────────────────────────

class OrdersLoaded extends OrderState {
  final List<Order> orders;
  final int totalOrders;
  final int totalPages;
  final int currentPage;

  const OrdersLoaded({
    required this.orders,
    required this.totalOrders,
    required this.totalPages,
    required this.currentPage,
  });

  @override
  List<Object?> get props => [orders, totalOrders, totalPages, currentPage];

  bool get hasMore => currentPage < totalPages;
}

// ── Cancel Order ──────────────────────────────────────────────────────────────

class CancelingOrder extends OrderState {}

class OrderCancelled extends OrderState {
  final String message;

  const OrderCancelled({required this.message});

  @override
  List<Object?> get props => [message];
}

class OrderCancelError extends OrderState {
  final String message;

  const OrderCancelError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Proposals ─────────────────────────────────────────────────────────────────

class ProposalsLoading extends OrderState {
  final int orderId;

  const ProposalsLoading(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class ProposalsLoaded extends OrderState {
  final int orderId;
  final List<Proposal> proposals;

  const ProposalsLoaded({required this.orderId, required this.proposals});

  @override
  List<Object?> get props => [orderId, proposals];
}

class ProposalsError extends OrderState {
  final int orderId;
  final String message;

  const ProposalsError(this.orderId, this.message);

  @override
  List<Object?> get props => [orderId, message];
}

// ── Proposal Update ───────────────────────────────────────────────────────────

class ProposalUpdating extends OrderState {}

class ProposalAccepted extends OrderState {
  final int orderId;
  final int proposalId;

  const ProposalAccepted({required this.orderId, required this.proposalId});

  @override
  List<Object?> get props => [orderId, proposalId];
}

class ProposalRejected extends OrderState {
  final int orderId;
  final int proposalId;

  const ProposalRejected({required this.orderId, required this.proposalId});

  @override
  List<Object?> get props => [orderId, proposalId];
}

// ── Delivery Confirmation ─────────────────────────────────────────────────────

class DeliveryConfirming extends OrderState {}

class DeliveryConfirmed extends OrderState {
  final int orderId;

  const DeliveryConfirmed({required this.orderId});

  @override
  List<Object?> get props => [orderId];
}

// ── Error ─────────────────────────────────────────────────────────────────────

class OrderError extends OrderState {
  final String message;

  const OrderError(this.message);

  @override
  List<Object?> get props => [message];
}