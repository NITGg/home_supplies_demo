import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/orders_model.dart';
import '../data/repositories/orders_repo.dart';
import 'orders_states.dart';

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;

  // Pagination tracking
  int _availableOrdersPage = 1;
  int _historyPage = 1;
  bool _isLoadingMoreAvailable = false;
  bool _isLoadingMoreHistory = false;
  String _currentHistoryFilter = 'all';

  // Cache for tracking local proposal submissions
  final Set<int> _localProposalCache = {};

  OrderCubit(this._repository) : super(AvailableOrdersInitial());

  // ============== Available Orders ==============
  Future<void> fetchAvailableOrders({
    bool refresh = false,
    int limit = 20,
  }) async {
    if (refresh) {
      _availableOrdersPage = 1;
      emit(const AvailableOrdersLoading());
    } else {
      if (_isLoadingMoreAvailable) return;
      _isLoadingMoreAvailable = true;

      // Show loading more indicator only if we have existing orders
      final currentState = state;
      if (currentState is AvailableOrdersLoaded) {
        emit(const AvailableOrdersLoading(isLoadingMore: true));
      } else {
        emit(const AvailableOrdersLoading());
      }
    }

    try {
      final result = await _repository.getAvailableOrders(
        page: _availableOrdersPage,
        limit: limit,
      );

      final newOrders = result['orders'] as List<OrderModel>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      final currentPage = pagination['page'] as int;
      final totalPages = pagination['totalPages'] as int;
      final hasMore = currentPage < totalPages;

      List<OrderModel> finalOrders = newOrders;

      // If loading more, append to existing orders
      if (!refresh && state is AvailableOrdersLoaded) {
        final existingOrders = (state as AvailableOrdersLoaded).orders;
        finalOrders = [...existingOrders, ...newOrders];
      }

      // Apply local proposal cache to mark orders
      finalOrders = _applyLocalProposalCache(finalOrders);

      emit(
        AvailableOrdersLoaded(
          orders: finalOrders,
          pagination: pagination,
          hasMore: hasMore,
        ),
      );

      _isLoadingMoreAvailable = false;
    } catch (e) {
      _isLoadingMoreAvailable = false;
      emit(AvailableOrdersError(_getErrorMessage(e)));
    }
  }

  Future<void> loadMoreAvailableOrders() async {
    final currentState = state;
    if (currentState is AvailableOrdersLoaded && currentState.hasMore) {
      _availableOrdersPage++;
      await fetchAvailableOrders();
    }
  }

  // ============== Order History ==============
  Future<void> fetchOrderHistory({
    bool refresh = false,
    String filter = 'all',
    int limit = 20,
  }) async {
    if (refresh || filter != _currentHistoryFilter) {
      _historyPage = 1;
      _currentHistoryFilter = filter;
      emit(const OrderHistoryLoading());
    } else {
      if (_isLoadingMoreHistory) return;
      _isLoadingMoreHistory = true;

      final currentState = state;
      if (currentState is OrderHistoryLoaded) {
        emit(const OrderHistoryLoading(isLoadingMore: true));
      } else {
        emit(const OrderHistoryLoading());
      }
    }

    try {
      final result = await _repository.getOrderHistory(
        page: _historyPage,
        limit: limit,
        filter: filter,
      );

      final newOrders = result['orders'] as List<OrderModel>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      final currentPage = pagination['page'] as int;
      final totalPages = pagination['totalPages'] as int;
      final hasMore = currentPage < totalPages;

      List<OrderModel> finalOrders = newOrders;

      // If loading more and same filter, append to existing orders
      if (!refresh &&
          filter == _currentHistoryFilter &&
          state is OrderHistoryLoaded) {
        final existingOrders = (state as OrderHistoryLoaded).orders;
        finalOrders = [...existingOrders, ...newOrders];
      }

      emit(
        OrderHistoryLoaded(
          orders: finalOrders,
          pagination: pagination,
          hasMore: hasMore,
          currentFilter: filter,
        ),
      );

      _isLoadingMoreHistory = false;
    } catch (e) {
      _isLoadingMoreHistory = false;
      emit(OrderHistoryError(_getErrorMessage(e)));
    }
  }

  Future<void> loadMoreHistory() async {
    final currentState = state;
    if (currentState is OrderHistoryLoaded && currentState.hasMore) {
      _historyPage++;
      await fetchOrderHistory(filter: currentState.currentFilter);
    }
  }

  // ============== Order Details ==============
  Future<void> fetchOrderDetails(
    int orderId, {
    bool fetchFeeRange = false,
  }) async {
    emit(OrderDetailsLoading());
    try {
      final order = await _repository.getOrderDetails(orderId);

      // Apply local cache to the order
      final updatedOrder = _applyLocalProposalToOrder(order);

      if (fetchFeeRange) {
        final feeRange = await _repository.getAllowedFeeRange(orderId);
        emit(OrderDetailsLoaded(order: updatedOrder, feeRange: feeRange));
      } else {
        emit(OrderDetailsLoaded(order: updatedOrder));
      }
    } catch (e) {
      emit(OrderDetailsError(_getErrorMessage(e)));
    }
  }

  // ============== Submit Offer ==============
  Future<void> submitOffer({
    required int orderId,
    required double totalFee,
  }) async {
    // Check for active order before submitting
    final hasActive = await hasActiveOrder();
    if (hasActive) {
      emit(
        const OfferSubmitError(
          'You already have an active order. Please complete it first.',
        ),
      );
      return;
    }

    emit(SubmittingOffer());
    try {
      final proposal = await _repository.submitOffer(
        orderId: orderId,
        totalFee: totalFee,
      );

      // Add to local cache immediately
      _localProposalCache.add(orderId);

      emit(OfferSubmitted(proposal, orderId));
    } catch (e) {
      emit(OfferSubmitError(_getErrorMessage(e)));
    }
  }

  // ============== Active Order ==============
  Future<void> fetchActiveOrder() async {
    emit(ActiveOrderLoading());
    try {
      final order = await _repository.getActiveOrder();
      if (order == null) {
        emit(NoActiveOrder());
      } else {
        emit(ActiveOrderLoaded(order));
      }
    } catch (e) {
      emit(ActiveOrderError(_getErrorMessage(e)));
    }
  }

  // ============== Complete Delivery ==============
  Future<void> completeDelivery({
    required int orderId,
    required double actualPrice,
  }) async {
    emit(CompletingDelivery());
    try {
      final qrCode = await _repository.completeDelivery(
        orderId: orderId,
        actualPrice: actualPrice,
      );
      emit(DeliveryCompleted(qrCode));
    } catch (e) {
      emit(DeliveryCompleteError(_getErrorMessage(e)));
    }
  }

  // ============== Report High Price ==============
  Future<void> reportHighPrice({
    required int orderId,
    required double actualPrice,
  }) async {
    emit(ReportingHighPrice());
    try {
      final order = await _repository.reportHighPrice(
        orderId: orderId,
        actualPrice: actualPrice,
      );
      emit(HighPriceReported(order));
    } catch (e) {
      emit(HighPriceReportError(_getErrorMessage(e)));
    }
  }

  // ============== Cancel Order ==============
  Future<void> cancelOrderUnavailable({
    required int orderId,
    String note = 'unavailable',
  }) async {
    emit(CancelingOrder());
    try {
      final order = await _repository.cancelOrderUnavailable(
        orderId: orderId,
        note: note,
      );
      emit(OrderCancelled(order));
    } catch (e) {
      emit(OrderCancelError(_getErrorMessage(e)));
    }
  }

  Future<void> cancelOrderOther({
    required int orderId,
    required String note,
  }) async {
    emit(CancelingOrder());
    try {
      final order = await _repository.cancelOrderOther(
        orderId: orderId,
        note: note,
      );
      emit(OrderCancelled(order));
    } catch (e) {
      emit(OrderCancelError(_getErrorMessage(e)));
    }
  }

  // ============== Helper Methods ==============
  Future<bool> hasActiveOrder() async {
    try {
      final order = await _repository.getActiveOrder();
      return order != null;
    } catch (e) {
      return false;
    }
  }

  // Update order in the current state after offer submission
  void markOrderAsOffered(int orderId) {
    // Add to local cache
    _localProposalCache.add(orderId);

    final currentState = state;
    if (currentState is AvailableOrdersLoaded) {
      final updatedOrders = currentState.orders.map((order) {
        if (order.id == orderId) {
          return order.copyWith(hasMyProposal: true);
        }
        return order;
      }).toList();

      emit(
        AvailableOrdersLoaded(
          orders: updatedOrders,
          pagination: currentState.pagination,
          hasMore: currentState.hasMore,
        ),
      );
    }
  }

  // Apply local proposal cache to a list of orders
  List<OrderModel> _applyLocalProposalCache(List<OrderModel> orders) {
    if (_localProposalCache.isEmpty) return orders;

    return orders.map((order) {
      if (_localProposalCache.contains(order.id)) {
        return order.copyWith(hasMyProposal: true);
      }
      return order;
    }).toList();
  }

  // Apply local proposal cache to a single order
  OrderModel _applyLocalProposalToOrder(OrderModel order) {
    if (_localProposalCache.contains(order.id)) {
      return order.copyWith(hasMyProposal: true);
    }
    return order;
  }

  // Clear local proposal cache (call when logging out or clearing data)
  void clearProposalCache() {
    _localProposalCache.clear();
  }

  // Reset pagination
  void resetPagination() {
    _availableOrdersPage = 1;
    _historyPage = 1;
    _isLoadingMoreAvailable = false;
    _isLoadingMoreHistory = false;
  }

  // Helper method to extract error messages
  String _getErrorMessage(dynamic error) {
    return error.toString().replaceAll('Exception:', '').trim();
  }
}
