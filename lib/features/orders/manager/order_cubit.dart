import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/order_model.dart';
import '../data/models/proposal_model.dart';
import '../data/repositories/order_repo.dart';
import 'order_states.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;

  /// Cached list so background operations never wipe the UI.
  OrdersLoaded? _lastLoadedState;

  OrderCubit({OrderRepository? repository})
      : _repository = repository ?? OrderRepository(),
        super(OrderInitial());

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Emits [OrderOperationLoading] while keeping the builder showing
  /// [_lastLoadedState] (the builder ignores [OrderOperationLoading] and
  /// falls through to showing the last known list).
  void _emitOperationLoading() => emit(OrderOperationLoading());

  /// After a mutating operation completes, restore the list so the UI
  /// never flickers to empty.
  void _restoreList() {
    if (_lastLoadedState != null) emit(_lastLoadedState!);
  }

  // ── Load Orders ────────────────────────────────────────────────────────────

  Future<void> loadOrders({int page = 1}) async {
    if (page == 1) {
      // Only show full-screen spinner if there is no cached list yet.
      if (_lastLoadedState == null) emit(OrderLoading());
    } else {
      emit(OrdersLoadingMore());
    }

    try {
      log('OrderCubit: Loading orders — page $page');
      final response = await _repository.getOrders(page: page);
      log('OrderCubit: Loaded ${response.orders.length} orders');

      final newState = page == 1
          ? OrdersLoaded(
        orders: response.orders,
        totalOrders: response.totalOrders,
        totalPages: response.totalPages,
        currentPage: page,
      )
          : OrdersLoaded(
        orders: [
          ...(_lastLoadedState?.orders ?? []),
          ...response.orders,
        ],
        totalOrders: response.totalOrders,
        totalPages: response.totalPages,
        currentPage: page,
      );

      _lastLoadedState = newState;
      emit(newState);
    } catch (e) {
      log('OrderCubit: Error loading orders: $e');
      emit(OrderError(e.toString()));
    }
  }

  // ── Create Order ───────────────────────────────────────────────────────────

  Future<void> createOrder(Order order) async {
    _emitOperationLoading();
    try {
      log('OrderCubit: Creating order');
      final response = await _repository.createOrder(order);
      log('OrderCubit: Order created — ${response.order.orderNumber}');

      emit(OrderSuccess(message: response.message, order: response.order));

      // Reload list in background; emits new OrdersLoaded when done.
      await loadOrders();
    } catch (e) {
      log('OrderCubit: Error creating order: $e');
      _restoreList();
      emit(OrderError(e.toString()));
    }
  }

  // ── Cancel Order (reason-based) ────────────────────────────────────────────

  Future<void> cancelOrder(int orderId, String reason) async {
    emit(CancelingOrder());
    try {
      log('OrderCubit: Cancelling order $orderId');
      await _repository.cancelOrder(orderId, reason);
      log('OrderCubit: Order cancelled');

      emit(const OrderCancelled(message: 'Order cancelled successfully'));
      await loadOrders();
    } catch (e) {
      log('OrderCubit: Error cancelling order: $e');
      emit(OrderCancelError(e.toString()));
    }
  }

  /// Cancel because the product is unavailable (no reason text required).
  Future<void> cancelOrderUnavailable({required int orderId}) =>
      cancelOrder(orderId, 'Product unavailable');

  /// Cancel with a custom other reason.
  Future<void> cancelOrderOther({
    required int orderId,
    required String note,
  }) =>
      cancelOrder(orderId, note);

  // ── Load Proposals ─────────────────────────────────────────────────────────

  Future<void> loadProposals(int orderId) async {
    emit(ProposalsLoading(orderId));
    try {
      log('OrderCubit: Loading proposals for order $orderId');
      final response = await _repository.getOrderProposals(orderId);
      log('OrderCubit: Loaded ${response.proposals.length} proposals');

      emit(ProposalsLoaded(orderId: orderId, proposals: response.proposals));
    } catch (e) {
      log('OrderCubit: Error loading proposals: $e');
      emit(ProposalsError(orderId, e.toString()));
    }
  }

  // ── Accept Proposal ────────────────────────────────────────────────────────

  Future<void> acceptProposal({
    required int orderId,
    required int proposalId,
  }) async {
    emit(ProposalUpdating());
    try {
      log('OrderCubit: Accepting proposal $proposalId for order $orderId');
      await _repository.updateProposalStatus(
        orderId: orderId,
        proposalId: proposalId,
        status: 'ACCEPTED',
      );
      log('OrderCubit: Proposal accepted');

      emit(ProposalAccepted(orderId: orderId, proposalId: proposalId));

      // Reload both list and proposals; restore list first so UI doesn't flicker.
      await loadOrders();
      await loadProposals(orderId);
    } catch (e) {
      log('OrderCubit: Error accepting proposal: $e');
      _restoreList();
      emit(OrderError(e.toString()));
    }
  }

  // ── Reject Proposal ────────────────────────────────────────────────────────

  Future<void> rejectProposal({
    required int orderId,
    required int proposalId,
  }) async {
    emit(ProposalUpdating());
    try {
      log('OrderCubit: Rejecting proposal $proposalId for order $orderId');
      await _repository.updateProposalStatus(
        orderId: orderId,
        proposalId: proposalId,
        status: 'REJECTED',
      );
      log('OrderCubit: Proposal rejected');

      emit(ProposalRejected(orderId: orderId, proposalId: proposalId));
      await loadProposals(orderId);
    } catch (e) {
      log('OrderCubit: Error rejecting proposal: $e');
      emit(OrderError(e.toString()));
    }
  }

  // ── Confirm Delivery ───────────────────────────────────────────────────────

  Future<void> confirmDelivery({
    required int orderId,
    required int courierId,
  }) async {
    emit(DeliveryConfirming());
    try {
      log('OrderCubit: Confirming delivery for order $orderId');
      await _repository.confirmDelivery(
        orderId: orderId,
        courierId: courierId,
      );
      log('OrderCubit: Delivery confirmed');

      emit(DeliveryConfirmed(orderId: orderId));
      await loadOrders();
    } catch (e) {
      log('OrderCubit: Error confirming delivery: $e');
      _restoreList();
      emit(OrderError(e.toString()));
    }
  }

  void reset() => emit(OrderInitial());
}