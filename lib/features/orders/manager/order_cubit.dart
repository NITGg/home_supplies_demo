import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/order_model.dart';
import '../data/models/proposal_model.dart';
import '../data/repositories/order_repo.dart';
import 'order_states.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;

  OrderCubit({
    OrderRepository? repository,
  })  : _repository = repository ?? OrderRepository(),
        super(OrderInitial());

  // Create Order
  Future<void> createOrder(Order order) async {
    emit(OrderLoading());
    try {
      log('OrderCubit: Creating order');
      final response = await _repository.createOrder(order);
      log('OrderCubit: Order created successfully - ${response.order.orderNumber}');

      emit(OrderSuccess(
        message: response.message,
        order: response.order,
      ));
    } catch (e) {
      log('OrderCubit: Error creating order: $e');
      emit(OrderError(e.toString()));
    }
  }

  // Load All Orders
  Future<void> loadOrders({int page = 1}) async {
    if (page == 1) {
      emit(OrderLoading());
    } else {
      emit(OrdersLoadingMore());
    }

    try {
      log('OrderCubit: Loading orders - page $page');
      final response = await _repository.getOrders(page: page);
      log('OrderCubit: Loaded ${response.orders.length} orders');

      if (page == 1) {
        emit(OrdersLoaded(
          orders: response.orders,
          totalOrders: response.totalOrders,
          totalPages: response.totalPages,
          currentPage: page,
        ));
      } else {
        // For pagination, we need to append to existing orders
        final currentState = state;
        if (currentState is OrdersLoaded) {
          emit(OrdersLoaded(
            orders: [...currentState.orders, ...response.orders],
            totalOrders: response.totalOrders,
            totalPages: response.totalPages,
            currentPage: page,
          ));
        }
      }
    } catch (e) {
      log('OrderCubit: Error loading orders: $e');
      emit(OrderError(e.toString()));
    }
  }

  // Cancel Order
  Future<void> cancelOrder(int orderId, String reason) async {
    emit(OrderLoading());
    try {
      log('OrderCubit: Cancelling order $orderId');
      final response = await _repository.cancelOrder(orderId, reason);
      log('OrderCubit: Order cancelled successfully');

      emit(OrderCancelled(
        message: 'Order cancelled successfully',
      ));

      // Reload orders after cancellation
      await loadOrders();
    } catch (e) {
      log('OrderCubit: Error cancelling order: $e');
      emit(OrderError(e.toString()));
    }
  }

  // Load Proposals for an Order
  Future<void> loadProposals(int orderId) async {
    emit(ProposalsLoading(orderId));
    try {
      log('OrderCubit: Loading proposals for order $orderId');
      final response = await _repository.getOrderProposals(orderId);
      log('OrderCubit: Loaded ${response.proposals.length} proposals');

      emit(ProposalsLoaded(
        orderId: orderId,
        proposals: response.proposals,
      ));
    } catch (e) {
      log('OrderCubit: Error loading proposals: $e');
      emit(ProposalsError(orderId, e.toString()));
    }
  }

  // Accept Proposal
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
      log('OrderCubit: Proposal accepted successfully');

      emit(ProposalAccepted(
        orderId: orderId,
        proposalId: proposalId,
      ));

      // Reload orders and proposals
      await loadOrders();
      await loadProposals(orderId);
    } catch (e) {
      log('OrderCubit: Error accepting proposal: $e');
      emit(OrderError(e.toString()));
    }
  }

  // Reject Proposal
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
      log('OrderCubit: Proposal rejected successfully');

      emit(ProposalRejected(
        orderId: orderId,
        proposalId: proposalId,
      ));

      // Reload proposals
      await loadProposals(orderId);
    } catch (e) {
      log('OrderCubit: Error rejecting proposal: $e');
      emit(OrderError(e.toString()));
    }
  }

  // Confirm Delivery (from QR Code)
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
      log('OrderCubit: Delivery confirmed successfully');

      emit(DeliveryConfirmed(orderId: orderId));

      // Reload orders
      await loadOrders();
    } catch (e) {
      log('OrderCubit: Error confirming delivery: $e');
      emit(OrderError(e.toString()));
    }
  }

  void reset() {
    emit(OrderInitial());
  }
}